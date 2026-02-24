import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../models/inference_result.dart';
import '../runtime/ocr_runtime.dart';
import '../runtime/stt_runtime.dart';
import '../runtime/tts_runtime.dart';
import '../runtime/llm_runtime.dart';
import '../runtime/embedding_runtime.dart';
import '../utils/logger.dart';

/// Platform Channel 名称
const String kModelRuntimeChannel = 'com.modelloader/model_runtime';

/// ONNX Runtime Flutter 实现
class ONNXRuntimes {
  static const MethodChannel _channel = MethodChannel(kModelRuntimeChannel);

  /// 获取 Channel 实例
  static MethodChannel get channel => _channel;

  /// OCR 运行时 ONNX 实现
  static final OCRRuntime ocr = _OCRRuntimeImpl();

  /// STT 运行时 ONNX 实现
  static final STTRuntime stt = _STTRuntimeImpl();

  /// Embedding 运行时 ONNX 实现
  static final EmbeddingRuntime embedding = _EmbeddingRuntimeImpl();

  /// TTS 运行时 (暂不支持 ONNX)
  static final TTSRuntime tts = _TTSRuntimeUnimplemented();

  /// LLM 运行时 (暂不支持 ONNX)
  static final LLMRuntime llm = _LLMRuntimeUnimplemented();
}

/// OCR Runtime ONNX 实现
class _OCRRuntimeImpl implements OCRRuntime {
  bool _loaded = false;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> loadModel(OCRConfig config) async {
    try {
      await ONNXRuntimes.channel.invokeMethod('loadOCRModel', {
        'modelPath': config.modelPath,
        'language': config.language,
      });
      _loaded = true;
      logger.info('OCR model loaded: ${config.modelPath}');
    } on PlatformException catch (e) {
      logger.error('Failed to load OCR model', e);
      rethrow;
    }
  }

  @override
  Future<void> unloadModel() async {
    try {
      await ONNXRuntimes.channel.invokeMethod('unloadOCRModel');
      _loaded = false;
      logger.info('OCR model unloaded');
    } on PlatformException catch (e) {
      logger.error('Failed to unload OCR model', e);
    }
  }

  @override
  Future<OCRResult> recognize(String imagePath, {OCRParams? params}) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      return await recognizeBytes(bytes, params: params);
    } catch (e) {
      logger.error('OCR recognition failed', e);
      rethrow;
    }
  }

  @override
  Future<OCRResult> recognizeBytes(Uint8List imageBytes, {OCRParams? params}) async {
    try {
      final result = await ONNXRuntimes.channel.invokeMethod('recognizeOCR', {
        'imageData': imageBytes,
        'language': params?.language ?? 'eng',
      });

      if (result is Map) {
        return OCRResult(
          text: result['text'] ?? '',
          blocks: const [],
          averageConfidence: (result['confidence'] ?? 0.0).toDouble(),
        );
      }

      throw Exception('Invalid OCR result');
    } on PlatformException catch (e) {
      logger.error('OCR recognition failed', e);
      rethrow;
    }
  }
}

/// STT Runtime ONNX 实现
class _STTRuntimeImpl implements STTRuntime {
  bool _loaded = false;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> loadModel(STTConfig config) async {
    try {
      await ONNXRuntimes.channel.invokeMethod('loadSTTModel', {
        'modelPath': config.modelPath,
        'language': config.language,
      });
      _loaded = true;
      logger.info('STT model loaded: ${config.modelPath}');
    } on PlatformException catch (e) {
      logger.error('Failed to load STT model', e);
      rethrow;
    }
  }

  @override
  Future<void> unloadModel() async {
    try {
      await ONNXRuntimes.channel.invokeMethod('unloadSTTModel');
      _loaded = false;
    } on PlatformException catch (e) {
      logger.error('Failed to unload STT model', e);
    }
  }

  @override
  Future<STTResult> recognize(String audioPath, {STTParams? params}) async {
    try {
      final bytes = await File(audioPath).readAsBytes();
      return await recognizeBytes(bytes, params: params);
    } catch (e) {
      logger.error('STT recognition failed', e);
      rethrow;
    }
  }

  @override
  Future<STTResult> recognizeBytes(Uint8List audioBytes, {STTParams? params}) async {
    try {
      final result = await ONNXRuntimes.channel.invokeMethod('recognizeSTT', {
        'audioData': audioBytes,
        'language': params?.language ?? 'auto',
      });

      if (result is Map) {
        return STTResult(
          text: result['text'] ?? '',
          confidence: (result['confidence'] ?? 0.0).toDouble(),
          language: result['language'],
        );
      }

      throw Exception('Invalid STT result');
    } on PlatformException catch (e) {
      logger.error('STT recognition failed', e);
      rethrow;
    }
  }

  @override
  Stream<STTResult> recognizeStream(Stream<Uint8List> audioStream, {STTParams? params}) {
    throw UnimplementedError('Stream recognition not implemented');
  }

  @override
  Future<List<String>> getSupportedLanguages() async {
    return ['en', 'zh', 'ja', 'ko', 'es', 'fr', 'de'];
  }
}

/// Embedding Runtime ONNX 实现
class _EmbeddingRuntimeImpl implements EmbeddingRuntime {
  bool _loaded = false;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> loadModel(EmbeddingConfig config) async {
    try {
      await ONNXRuntimes.channel.invokeMethod('loadEmbeddingModel', {
        'modelPath': config.modelPath,
        'tokenizerPath': config.tokenizerPath,
        'maxLength': config.maxLength,
      });
      _loaded = true;
      logger.info('Embedding model loaded: ${config.modelPath}');
    } on PlatformException catch (e) {
      logger.error('Failed to load Embedding model', e);
      rethrow;
    }
  }

  @override
  Future<void> unloadModel() async {
    try {
      await ONNXRuntimes.channel.invokeMethod('unloadEmbeddingModel');
      _loaded = false;
      logger.info('Embedding model unloaded');
    } on PlatformException catch (e) {
      logger.error('Failed to unload Embedding model', e);
    }
  }

  @override
  Future<EmbeddingResult> getEmbedding(String text) async {
    try {
      final result = await ONNXRuntimes.channel.invokeMethod('getEmbedding', {
        'text': text,
      });

      if (result is Map) {
        // Convert Map<dynamic, dynamic> to Map<String, dynamic>
        final Map<String, dynamic> typedResult = Map<String, dynamic>.from(result);
        return EmbeddingResult.fromJson(typedResult);
      }

      throw Exception('Invalid Embedding result');
    } on PlatformException catch (e) {
      logger.error('Get embedding failed', e);
      rethrow;
    }
  }
}

/// TTS 未实现
class _TTSRuntimeUnimplemented implements TTSRuntime {
  @override
  bool get isLoaded => false;

  @override
  Future<void> loadModel(TTSConfig config) async {
    throw UnimplementedError('TTS via ONNX not implemented');
  }

  @override
  Future<void> unloadModel() async {}

  @override
  Future<String> synthesize(String text, {TTSParams? params, String? outputPath}) async {
    throw UnimplementedError('TTS not implemented');
  }

  @override
  Future<Uint8List> synthesizeBytes(String text, {TTSParams? params}) async {
    throw UnimplementedError('TTS not implemented');
  }

  @override
  Future<List<String>> getAvailableVoices() async => [];
}

/// LLM 未实现
class _LLMRuntimeUnimplemented implements LLMRuntime {
  @override
  LLMModelInfo? get loadedModel => null;

  @override
  bool get isLoaded => false;

  @override
  Future<void> loadModel(LLMConfig config) async {
    throw UnimplementedError('LLM via ONNX not implemented. Use llama.cpp for desktop.');
  }

  @override
  Future<void> unloadModel() async {}

  @override
  Future<String> complete(String prompt, {GenerationConfig? config}) async {
    throw UnimplementedError('LLM not implemented');
  }

  @override
  Stream<String> completeStream(String prompt, {GenerationConfig? config}) async* {
    throw UnimplementedError('LLM not implemented');
  }

  @override
  Future<String> chat(List<ChatMessage> messages, {GenerationConfig? config}) async {
    throw UnimplementedError('LLM not implemented');
  }

  @override
  Stream<String> chatStream(List<ChatMessage> messages, {GenerationConfig? config}) async* {
    throw UnimplementedError('LLM not implemented');
  }
}
