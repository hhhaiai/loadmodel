import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../runtime/llm_runtime.dart';
import '../utils/logger.dart';
import '../core/platform_utils.dart';

/// LLM Runtime llama.cpp 实现 (桌面端)
class LLMRuntimeLlamaCpp implements LLMRuntime {
  LLMModelInfo? _loadedModelInfo;
  bool _loaded = false;
  Process? _llamaProcess;
  int _serverPort = 8080;

  // 请求计数器
  int _requestCounter = 0;

  // llama.cpp 可执行文件路径
  final String? llamaBinPath;

  // 默认端口
  static const int _defaultPort = 8080;

  LLMRuntimeLlamaCpp({this.llamaBinPath});

  @override
  LLMModelInfo? get loadedModel => _loadedModelInfo;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> loadModel(LLMConfig config) async {
    if (!PlatformUtils.isDesktop) {
      throw UnsupportedError('LLMRuntimeLlamaCpp only supports desktop platforms');
    }

    try {
      // 查找 llama.cpp 可执行文件
      final binPath = llamaBinPath ?? await _findLlamaBin();
      if (binPath == null) {
        throw Exception('llama.cpp binary not found. Please install llama.cpp first.');
      }

      // 查找可用端口
      _serverPort = await _findAvailablePort(_defaultPort);

      _llamaProcess = await Process.start(
        binPath,
        [
          '-m', config.modelPath,
          '-c', config.contextLength.toString(),
          '-t', '4',
          '--port', _serverPort.toString(),
          '--host', '127.0.0.1',
          '--log-disable',
        ],
      );

      // 捕获进程输出用于调试
      _llamaProcess!.stdout.transform(const SystemEncoding().decoder).forEach((line) {
        logger.info('[llama-server stdout]: $line');
      });
      _llamaProcess!.stderr.transform(const SystemEncoding().decoder).forEach((line) {
        logger.info('[llama-server stderr]: $line');
      });

      // 等待服务启动 (模型加载需要较长时间，首次可能需要 60-120 秒)
      logger.info('Waiting for llama-server to start (this may take 60-120 seconds)...');
      await _waitForServer(_serverPort, timeout: const Duration(seconds: 120));
      logger.info('Llama server started successfully!');

      _loadedModelInfo = LLMModelInfo(
        name: config.modelPath.split('/').last,
        path: config.modelPath,
        contextLength: config.contextLength,
        hardware: config.gpuLayers != null && config.gpuLayers! > 0 ? 'GPU' : 'CPU',
      );

      _loaded = true;
      logger.info('LLM model loaded: ${config.modelPath} on port $_serverPort');
    } catch (e) {
      logger.error('Failed to load LLM model', e);
      _loaded = false;
      rethrow;
    }
  }

  @override
  Future<void> unloadModel() async {
    if (_llamaProcess != null) {
      _llamaProcess!.kill();
      _llamaProcess = null;
    }
    _loaded = false;
    _loadedModelInfo = null;
    logger.info('LLM model unloaded');
  }

  @override
  Future<String> complete(String prompt, {GenerationConfig? config}) async {
    final requestId = _generateRequestId();
    try {
      // 构建请求体
      final body = <String, dynamic>{
        'prompt': prompt,
        'n_predict': config?.maxTokens ?? 2048,
        'temperature': config?.temperature ?? 0.7,
        'top_p': config?.topP ?? 0.9,
        'stream': false,
      };

      // 添加可选参数
      if (config?.topK != null) body['top_k'] = config!.topK;
      if (config?.repeatPenalty != null) body['repeat_penalty'] = config!.repeatPenalty;
      if (config?.seed != null) body['seed'] = config!.seed;
      if (config?.stopStrings != null && config!.stopStrings!.isNotEmpty) {
        body['stop'] = config.stopStrings;
      }

      final response = await _callLlamaServer(
        '/completion',
        body,
        requestId: requestId,
      );

      return response['content'] ?? '';
    } catch (e) {
      logger.error('LLM completion failed', e);
      rethrow;
    }
  }

  @override
  Stream<String> completeStream(String prompt, {GenerationConfig? config}) async* {
    try {
      // 构建请求体
      final body = <String, dynamic>{
        'prompt': prompt,
        'n_predict': config?.maxTokens ?? 2048,
        'temperature': config?.temperature ?? 0.7,
        'top_p': config?.topP ?? 0.9,
        'stream': true,
      };

      // 添加可选参数
      if (config?.topK != null) body['top_k'] = config!.topK;
      if (config?.repeatPenalty != null) body['repeat_penalty'] = config!.repeatPenalty;
      if (config?.seed != null) body['seed'] = config!.seed;
      if (config?.stopStrings != null && config!.stopStrings!.isNotEmpty) {
        body['stop'] = config.stopStrings;
      }

      // Stop strings matcher for cross-chunk matching
      final stopMatcher = config?.stopStrings != null && config!.stopStrings!.isNotEmpty
          ? StopStringsMatcher(config.stopStrings!)
          : null;

      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('http://127.0.0.1:$_serverPort/completion'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));

      final response = await request.close();

      await for (final chunk in response.transform(const SystemEncoding().decoder)) {
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data.isNotEmpty && data != '[DONE]') {
              try {
                final json = jsonDecode(data) as Map<String, dynamic>;
                final content = json['content'] as String? ?? '';

                // Check for stop strings
                if (stopMatcher != null) {
                  final (matched, processed, _) = stopMatcher.addChunk(content);
                  if (matched) {
                    // Stop string matched, yield remaining and break
                    if (processed.isNotEmpty) {
                      yield processed;
                    }
                    return;
                  }
                  yield content;
                } else {
                  yield content;
                }
              } catch (_) {
                // Skip invalid JSON
              }
            }
          }
        }
      }
    } catch (e) {
      logger.error('LLM stream failed', e);
      yield* Stream.error(e);
    }
  }

  @override
  Future<String> chat(List<ChatMessage> messages, {GenerationConfig? config}) async {
    try {
      // 转换为 prompt 格式
      final prompt = _messagesToPrompt(messages);
      return await complete(prompt, config: config);
    } catch (e) {
      logger.error('LLM chat failed', e);
      rethrow;
    }
  }

  @override
  Stream<String> chatStream(List<ChatMessage> messages, {GenerationConfig? config}) async* {
    final prompt = _messagesToPrompt(messages);
    yield* completeStream(prompt, config: config);
  }

  /// 生成请求 ID
  String _generateRequestId() {
    _requestCounter++;
    return 'req_$_requestCounter';
  }

  /// 查找 llama.cpp 可执行文件
  Future<String?> _findLlamaBin() async {
    // 首先检查系统安装的 llama-server
    final systemPaths = [
      '/opt/homebrew/bin/llama-server',
      '/opt/homebrew/bin/llama-cli',
      '/usr/local/bin/llama-server',
      '/usr/local/bin/llama-cli',
    ];

    for (final path in systemPaths) {
      if (await File(path).exists()) {
        logger.info('Using system llama: $path');
        return path;
      }
    }

    // 尝试打包的 llama-server
    final bundlePath = _getBundledLlamaServer();
    if (bundlePath != null && await File(bundlePath).exists()) {
      logger.info('Using bundled llama-server: $bundlePath');
      return bundlePath;
    }

    // 检查 PATH
    final pathEnv = Platform.environment['PATH'] ?? '';
    final paths = pathEnv.split(':');
    for (final dir in paths) {
      final serverPath = '$dir/llama-server';
      if (await File(serverPath).exists()) {
        return serverPath;
      }
      final cliPath = '$dir/llama-cli';
      if (await File(cliPath).exists()) {
        return cliPath;
      }
    }

    return null;
  }

  /// 获取打包的 llama-server 路径
  String? _getBundledLlamaServer() {
    final executable = Platform.resolvedExecutable;
    final bundleDir = File(executable).parent.path;
    logger.info('Executable: $executable');
    logger.info('Bundle dir: $bundleDir');

    if (bundleDir.endsWith('/MacOS')) {
      final resourcesDir = bundleDir.replaceAll('/MacOS', '/Resources/llama/llama-server');
      logger.info('Resources path: $resourcesDir');
      return resourcesDir;
    }

    return null;
  }

  /// 查找可用端口
  Future<int> _findAvailablePort(int startPort) async {
    for (int port = startPort; port < startPort + 100; port++) {
      try {
        final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
        await socket.close();
        return port;
      } catch (_) {
        continue;
      }
    }
    throw Exception('No available port found');
  }

  /// 等待服务启动
  Future<void> _waitForServer(int port, {Duration timeout = const Duration(seconds: 120)}) async {
    final endTime = DateTime.now().add(timeout);
    int attempt = 0;
    while (DateTime.now().isBefore(endTime)) {
      attempt++;
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 2);
        final request = await client.getUrl(Uri.parse('http://127.0.0.1:$port/models'));
        final response = await request.close();
        if (response.statusCode == 200) {
          logger.info('Server is ready after $attempt attempts');
          return;
        }
      } catch (e) {
        if (attempt % 10 == 0) {
          logger.info('Waiting for server... attempt $attempt');
        }
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    throw Exception('Server failed to start within $timeout seconds');
  }

  /// 调用 llama.cpp server API
  Future<Map<String, dynamic>> _callLlamaServer(
    String endpoint,
    Map<String, dynamic> body, {
    String? requestId,
  }) async {
    final client = HttpClient();
    final request = await client.postUrl(Uri.parse('http://127.0.0.1:$_serverPort$endpoint'));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));

    final response = await request.close();
    final content = await response.transform(const Utf8Codec().decoder).join();

    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      logger.warning('Failed to parse server response: $content');
      return {'content': content};
    }
  }

  /// 将消息列表转换为 prompt
  String _messagesToPrompt(List<ChatMessage> messages) {
    final buffer = StringBuffer();
    for (final msg in messages) {
      switch (msg.role) {
        case ChatRole.system:
          buffer.writeln('system: ${msg.content}');
          break;
        case ChatRole.user:
          buffer.writeln('user: ${msg.content}');
          break;
        case ChatRole.assistant:
          buffer.writeln('assistant: ${msg.content}');
          break;
      }
    }
    buffer.write('assistant: ');
    return buffer.toString();
  }
}
