import 'dart:async';
import 'dart:io';
import '../models/inference_result.dart';
import '../runtime/llm_runtime.dart';
import '../utils/logger.dart';
import '../core/platform_utils.dart';

/// LLM Runtime llama.cpp 实现 (桌面端)
class LLMRuntimeLlamaCpp implements LLMRuntime {
  LLMModelInfo? _loadedModelInfo;
  bool _loaded = false;
  Process? _llamaProcess;

  // llama.cpp 可执行文件路径
  final String? llamaBinPath;

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

      // 启动 llama.cpp 服务进程
      _llamaProcess = await Process.start(
        binPath,
        [
          '-m', config.modelPath,
          '--ctx-size', config.contextLength.toString(),
          '--threads', (config.threads ?? 4).toString(),
          if (config.gpuLayers != null && config.gpuLayers! > 0)
            '--gpu-layers', config.gpuLayers.toString(),
          '--port', '8080',
          '--host', '127.0.0.1',
        ],
      );

      // 等待服务启动
      await Future.delayed(const Duration(seconds: 2));

      _loadedModelInfo = LLMModelInfo(
        name: config.modelPath.split('/').last,
        path: config.modelPath,
        contextLength: config.contextLength,
        hardware: config.gpuLayers != null && config.gpuLayers! > 0 ? 'GPU' : 'CPU',
      );

      _loaded = true;
      logger.info('LLM model loaded: ${config.modelPath}');
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
    // 通过 HTTP API 调用
    try {
      final response = await _callLlamaAPI({
        'prompt': prompt,
        'n_predict': config?.maxTokens ?? 2048,
        'temperature': config?.temperature ?? 0.7,
        'top_p': config?.topP ?? 0.9,
        'stream': false,
      });
      return response['content'] ?? '';
    } catch (e) {
      logger.error('LLM completion failed', e);
      rethrow;
    }
  }

  @override
  Stream<String> completeStream(String prompt, {GenerationConfig? config}) async* {
    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('http://127.0.0.1:8080/completion'));
      request.headers.contentType = ContentType.json;
      request.write({
        'prompt': prompt,
        'n_predict': config?.maxTokens ?? 2048,
        'temperature': config?.temperature ?? 0.7,
        'top_p': config?.topP ?? 0.9,
        'stream': true,
      });

      final response = await request.close();
      await for (final chunk in response.transform(const SystemEncoding().decoder)) {
        // 解析流式响应
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data.isNotEmpty && data != '[DONE]') {
              // 提取 content
              // 简化处理
              yield data;
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

  /// 查找 llama.cpp 可执行文件
  Future<String?> _findLlamaBin() async {
    // 检查 PATH 中是否有 llama
    final pathEnv = Platform.environment['PATH'] ?? '';
    final paths = pathEnv.split(':');

    for (final dir in paths) {
      final binPath = '$dir/llama';
      if (await File(binPath).exists()) {
        return binPath;
      }
    }

    // 检查常见安装位置
    final commonPaths = [
      '/usr/local/bin/llama',
      '/usr/bin/llama',
      '${Platform.environment['HOME']}/.local/bin/llama',
      '${Platform.environment['HOME']}/llama.cpp/build/bin/llama',
    ];

    for (final path in commonPaths) {
      if (await File(path).exists()) {
        return path;
      }
    }

    return null;
  }

  /// 调用 llama.cpp HTTP API
  Future<Map<String, dynamic>> _callLlamaAPI(Map<String, dynamic> body) async {
    final client = HttpClient();
    final request = await client.postUrl(Uri.parse('http://127.0.0.1:8080/completion'));
    request.headers.contentType = ContentType.json;
    request.write(body);

    final response = await request.close();
    final content = await response.transform(const SystemEncoding().decoder).join();

    // 简单解析 JSON
    // 实际实现需要更完善的解析
    return {'content': content};
  }

  /// 将消息列表转换为 prompt
  String _messagesToPrompt(List<ChatMessage> messages) {
    final buffer = StringBuffer();
    for (final msg in messages) {
      switch (msg.role) {
        case ChatRole.system:
          buffer.writeln('SYSTEM: ${msg.content}');
          break;
        case ChatRole.user:
          buffer.writeln('USER: ${msg.content}');
          break;
        case ChatRole.assistant:
          buffer.writeln('ASSISTANT: ${msg.content}');
          break;
      }
    }
    buffer.write('ASSISTANT: ');
    return buffer.toString();
  }
}
