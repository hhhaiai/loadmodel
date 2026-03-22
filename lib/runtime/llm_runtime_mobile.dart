import 'dart:async';
import 'package:flutter/services.dart';
import '../runtime/llm_runtime.dart';
import '../utils/logger.dart';

/// LLM Runtime for mobile platforms (iOS/Android)
/// Uses MethodChannel to call native plugin (no localhost HTTP path).
class LLMRuntimeMobile implements LLMRuntime {
  static const String _channelName = 'com.modelloader/model_runtime';

  final MethodChannel _channel;
  LLMModelInfo? _loadedModelInfo;
  bool _loaded = false;

  LLMRuntimeMobile({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  @override
  LLMModelInfo? get loadedModel => _loadedModelInfo;

  @override
  bool get isLoaded => _loaded;

  int _clampMaxTokens(int value) => value.clamp(1, 2048).toInt();

  double _clampTemperature(double value) => value.clamp(0.0, 2.0).toDouble();

  double _clampTopP(double value) => value.clamp(0.05, 1.0).toDouble();

  String _validateModelPath(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      throw PlatformException(
        code: 'INVALID_ARGS',
        message: 'modelPath required',
      );
    }
    if (!normalized.toLowerCase().endsWith('.gguf')) {
      throw PlatformException(
        code: 'INVALID_ARGS',
        message: 'modelPath must be a .gguf file path',
      );
    }
    return normalized;
  }

  @override
  Future<void> loadModel(LLMConfig config) async {
    try {
      final loaded = await _channel.invokeMethod<bool>('loadLLMModel', {
        'modelPath': _validateModelPath(config.modelPath),
        'contextLength': config.contextLength,
        'maxTokens': _clampMaxTokens(config.maxTokens),
        'temperature': _clampTemperature(config.temperature),
        'topP': _clampTopP(config.topP),
        if (config.gpuLayers != null) 'gpuLayers': config.gpuLayers,
        if (config.tokenizerPath != null) 'tokenizerPath': config.tokenizerPath,
        if (config.threads != null) 'threads': config.threads,
        'useGpu': config.useGpu,
      });

      if (loaded != true) {
        throw PlatformException(
          code: 'LOAD_ERROR',
          message: 'Native runtime failed to load model',
        );
      }

      _loadedModelInfo = LLMModelInfo(
        name: config.modelPath.split('/').last,
        path: config.modelPath,
        contextLength: config.contextLength,
        hardware: 'Mobile Native',
      );
      _loaded = true;
      logger.info(
        'Mobile LLM model loaded via MethodChannel: ${config.modelPath}',
      );
    } on PlatformException catch (e) {
      _loaded = false;
      _loadedModelInfo = null;
      logger.error('Failed to load mobile LLM model', e);
      rethrow;
    }
  }

  @override
  Future<void> unloadModel() async {
    try {
      await _channel.invokeMethod<bool>('unloadLLMModel');
    } on PlatformException catch (e) {
      logger.error('Failed to unload mobile LLM model', e);
    } finally {
      _loaded = false;
      _loadedModelInfo = null;
    }
  }

  @override
  Future<String> complete(String prompt, {GenerationConfig? config}) async {
    return chat([ChatMessage.user(prompt)], config: config);
  }

  @override
  Stream<String> completeStream(
    String prompt, {
    GenerationConfig? config,
  }) async* {
    yield* chatStream([ChatMessage.user(prompt)], config: config);
  }

  @override
  Future<String> chat(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  }) async {
    if (!_loaded) {
      throw StateError('LLM model is not loaded');
    }

    try {
      final result = await _channel.invokeMethod<dynamic>('chatLLM', {
        'messages': messages.map((m) => m.toJson()).toList(),
        'temperature': _clampTemperature(config?.temperature ?? 0.7),
        'maxTokens': _clampMaxTokens(config?.maxTokens ?? 2048),
        'topP': _clampTopP(config?.topP ?? 0.9),
        if (config?.topK != null) 'topK': config!.topK,
        if (config?.repeatPenalty != null)
          'repeatPenalty': config!.repeatPenalty,
        if (config?.seed != null) 'seed': config!.seed,
      });

      if (result is String) {
        return result;
      }

      return result?.toString() ?? '';
    } on PlatformException catch (e) {
      if (e.code == 'NOT_LOADED' || e.code == 'NATIVE_UNAVAILABLE') {
        _loaded = false;
        _loadedModelInfo = null;
      }
      logger.error('Mobile LLM chat failed', e);
      rethrow;
    }
  }

  @override
  Stream<String> chatStream(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  }) async* {
    if (!_loaded) {
      throw StateError('LLM model is not loaded');
    }

    Future<String> fallbackChat() async {
      final fallback = (await chat(messages, config: config)).trim();
      if (fallback.isNotEmpty) {
        return fallback;
      }
      throw PlatformException(
        code: 'INFERENCE_FAILED',
        message: 'Native LLM returned empty response',
      );
    }

    try {
      final result = await _channel.invokeMethod<dynamic>('chatLLMStream', {
        'messages': messages.map((m) => m.toJson()).toList(),
        'temperature': _clampTemperature(config?.temperature ?? 0.7),
        'maxTokens': _clampMaxTokens(config?.maxTokens ?? 2048),
        'topP': _clampTopP(config?.topP ?? 0.9),
        if (config?.topK != null) 'topK': config!.topK,
        if (config?.repeatPenalty != null)
          'repeatPenalty': config!.repeatPenalty,
        if (config?.seed != null) 'seed': config!.seed,
      });

      final streamText = (result is String ? result : result?.toString() ?? '')
          .trim();
      if (streamText.isNotEmpty) {
        yield streamText;
        return;
      }

      yield await fallbackChat();
    } on PlatformException catch (e) {
      if (e.code == 'NOT_IMPLEMENTED') {
        yield await fallbackChat();
        return;
      }
      if (e.code == 'NOT_LOADED' || e.code == 'NATIVE_UNAVAILABLE') {
        _loaded = false;
        _loadedModelInfo = null;
      }
      logger.error('Mobile LLM chat stream failed', e);
      rethrow;
    }
  }
}
