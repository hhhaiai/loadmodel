import 'dart:io';
import 'package:flutter/services.dart';
import '../models/inference_result.dart';
import '../runtime/ocr_runtime.dart';
import '../runtime/stt_runtime.dart';
import '../runtime/tts_runtime.dart';
import '../runtime/llm_runtime.dart';
import '../runtime/embedding_runtime.dart';
import '../runtime/image_caption_runtime.dart';
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

  /// TTS 运行时 (Android TextToSpeech / iOS AVSpeechSynthesizer)
  static final TTSRuntime tts = _TTSRuntimeImpl();

  /// Image Captioning 运行时 ONNX 实现
  static final ImageCaptionRuntime imageCaption = _ImageCaptionRuntimeImpl();

  /// LLM 运行时 (暂不支持 ONNX)
  static final LLMRuntime llm = _LLMRuntimeUnimplemented();
}

/// OCR Runtime ONNX 实现
bool _isValidOnnxLocalModelPath(String modelPath) {
  if (modelPath.isEmpty) {
    return false;
  }
  final normalized = modelPath.toLowerCase();
  if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
    return false;
  }
  return normalized.endsWith('.onnx');
}

bool _looksLikePlaceholderInferenceText(String text) {
  final normalized = text.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }

  const placeholderMarkers = [
    'placeholder',
    'model-specific implementation required',
    'model-specific preprocessing required',
    'post-processing required',
    'speech recognition result',
    'ocr result',
  ];

  return placeholderMarkers.any(normalized.contains);
}

Never _throwPlaceholderRuntimeUnavailable({
  required String taskLabel,
  required String text,
}) {
  throw PlatformException(
    code: 'RUNTIME_NOT_AVAILABLE',
    message:
        '$taskLabel runtime is still using a placeholder implementation: $text',
  );
}

class _OCRRuntimeImpl implements OCRRuntime {
  bool _loaded = false;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> loadModel(OCRConfig config) async {
    if (!_isValidOnnxLocalModelPath(config.modelPath)) {
      throw PlatformException(
        code: 'INVALID_ARGS',
        message: 'modelPath must be a local .onnx file path',
      );
    }

    try {
      final loaded = await ONNXRuntimes.channel.invokeMethod('loadOCRModel', {
        'modelPath': config.modelPath,
        'language': config.language,
      });
      if (loaded == false) {
        throw PlatformException(
          code: 'LOAD_ERROR',
          message: 'Native runtime failed to load OCR model',
        );
      }
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
  Future<OCRResult> recognizeBytes(
    Uint8List imageBytes, {
    OCRParams? params,
  }) async {
    try {
      final result = await ONNXRuntimes.channel.invokeMethod('recognizeOCR', {
        'imageData': imageBytes,
        'language': params?.language ?? 'eng',
      });

      if (result is Map) {
        final text = result['text']?.toString() ?? '';
        final confidence = (result['confidence'] ?? 0.0).toDouble();
        if (_looksLikePlaceholderInferenceText(text) && confidence <= 0.0) {
          _throwPlaceholderRuntimeUnavailable(taskLabel: 'OCR', text: text);
        }

        return OCRResult(
          text: text,
          blocks: const [],
          averageConfidence: confidence,
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
    if (!_isValidOnnxLocalModelPath(config.modelPath)) {
      throw PlatformException(
        code: 'INVALID_ARGS',
        message: 'modelPath must be a local .onnx file path',
      );
    }

    try {
      final loaded = await ONNXRuntimes.channel.invokeMethod('loadSTTModel', {
        'modelPath': config.modelPath,
        'language': config.language,
      });
      if (loaded == false) {
        throw PlatformException(
          code: 'LOAD_ERROR',
          message: 'Native runtime failed to load STT model',
        );
      }
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
  Future<STTResult> recognizeBytes(
    Uint8List audioBytes, {
    STTParams? params,
  }) async {
    try {
      final result = await ONNXRuntimes.channel.invokeMethod('recognizeSTT', {
        'audioData': audioBytes,
        'language': params?.language ?? 'auto',
      });

      if (result is Map) {
        final text = result['text']?.toString() ?? '';
        final confidence = (result['confidence'] ?? 0.0).toDouble();
        if (_looksLikePlaceholderInferenceText(text) && confidence <= 0.0) {
          _throwPlaceholderRuntimeUnavailable(taskLabel: 'STT', text: text);
        }

        return STTResult(
          text: text,
          confidence: confidence,
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
  Stream<STTResult> recognizeStream(
    Stream<Uint8List> audioStream, {
    STTParams? params,
  }) async* {
    yield* Stream.error(UnimplementedError('Stream recognition not implemented'));
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
    if (!_isValidOnnxLocalModelPath(config.modelPath)) {
      throw PlatformException(
        code: 'INVALID_ARGS',
        message: 'modelPath must be a local .onnx file path',
      );
    }

    try {
      final loaded = await ONNXRuntimes.channel
          .invokeMethod('loadEmbeddingModel', {
            'modelPath': config.modelPath,
            'tokenizerPath': config.tokenizerPath,
            'maxLength': config.maxLength,
          });
      if (loaded == false) {
        throw PlatformException(
          code: 'LOAD_ERROR',
          message: 'Native runtime failed to load embedding model',
        );
      }
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
        final Map<String, dynamic> typedResult = Map<String, dynamic>.from(
          result,
        );
        return EmbeddingResult.fromJson(typedResult);
      }

      throw Exception('Invalid Embedding result');
    } on PlatformException catch (e) {
      logger.error('Get embedding failed', e);
      rethrow;
    }
  }
}

/// TTS Runtime Platform 实现
class _TTSRuntimeImpl implements TTSRuntime {
  bool _loaded = false;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> loadModel(TTSConfig config) async {
    try {
      final loaded = await ONNXRuntimes.channel.invokeMethod('loadTTSModel', {
        'language': config.language ?? 'en-US',
      });
      if (loaded == false) {
        throw PlatformException(
          code: 'LOAD_ERROR',
          message: 'Native runtime failed to load TTS model',
        );
      }
      _loaded = true;
      logger.info('TTS model loaded');
    } on PlatformException catch (e) {
      logger.error('Failed to load TTS model', e);
      rethrow;
    }
  }

  @override
  Future<void> unloadModel() async {
    try {
      await ONNXRuntimes.channel.invokeMethod('unloadTTSModel');
      _loaded = false;
    } on PlatformException catch (e) {
      logger.error('Failed to unload TTS model', e);
    }
  }

  @override
  Future<String> synthesize(
    String text, {
    TTSParams? params,
    String? outputPath,
  }) async {
    if (outputPath == null || outputPath.isEmpty) {
      throw PlatformException(
        code: 'INVALID_ARGS',
        message: 'outputPath is required for TTS synthesis',
      );
    }

    try {
      final result = await ONNXRuntimes.channel.invokeMethod('synthesizeTTS', {
        'text': text,
        'outputPath': outputPath,
        if (params != null) ...{
          if (params.speed != null) 'speed': params.speed,
          if (params.pitch != null) 'pitch': params.pitch,
          if (params.volume != null) 'volume': params.volume,
          if (params.voice != null) 'voice': params.voice,
        },
      });

      if (result == null) {
        throw PlatformException(
          code: 'SYNTHESIS_ERROR',
          message: 'TTS synthesis returned null',
        );
      }

      return result.toString();
    } on PlatformException catch (e) {
      logger.error('TTS synthesis failed', e);
      rethrow;
    }
  }

  @override
  Future<Uint8List> synthesizeBytes(String text, {TTSParams? params}) async {
    // Generate to temp file first, then read bytes
    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.wav');
    try {
      await synthesize(text, params: params, outputPath: tempFile.path);
      final bytes = await tempFile.readAsBytes();
      return bytes;
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  @override
  Future<List<String>> getAvailableVoices() async {
    // Android TTS doesn't provide a direct API to list voices
    // Return common voice identifiers
    return ['en-US', 'zh-CN', 'ja-JP', 'ko-KR', 'es-ES', 'fr-FR', 'de-DE'];
  }
}

/// LLM 未实现
class _LLMRuntimeUnimplemented implements LLMRuntime {
  @override
  LLMModelInfo? get loadedModel => null;

  @override
  bool get isLoaded => false;

  @override
  Future<void> loadModel(LLMConfig config) async {
    throw UnimplementedError(
      'LLM via ONNX not implemented. Use llama.cpp for desktop.',
    );
  }

  @override
  Future<void> unloadModel() async {}

  @override
  Future<String> complete(String prompt, {GenerationConfig? config}) async {
    throw UnimplementedError('LLM not implemented');
  }

  @override
  Stream<String> completeStream(
    String prompt, {
    GenerationConfig? config,
  }) async* {
    throw UnimplementedError('LLM not implemented');
  }

  @override
  Future<String> chat(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  }) async {
    throw UnimplementedError('LLM not implemented');
  }

  @override
  Stream<String> chatStream(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  }) async* {
    throw UnimplementedError('LLM not implemented');
  }
}

/// Image Captioning Runtime ONNX 实现
class _ImageCaptionRuntimeImpl implements ImageCaptionRuntime {
  bool _loaded = false;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> loadModel(ImageCaptionConfig config) async {
    if (!_isValidOnnxLocalModelPath(config.modelPath)) {
      throw PlatformException(
        code: 'INVALID_ARGS',
        message: 'modelPath must be a local .onnx file path',
      );
    }

    try {
      final loaded = await ONNXRuntimes.channel.invokeMethod('loadImageCaptionModel', {
        'modelPath': config.modelPath,
      });
      if (loaded == false) {
        throw PlatformException(
          code: 'LOAD_ERROR',
          message: 'Native runtime failed to load Image Captioning model',
        );
      }
      _loaded = true;
      logger.info('Image Captioning model loaded: ${config.modelPath}');
    } on PlatformException catch (e) {
      logger.error('Failed to load Image Captioning model', e);
      rethrow;
    }
  }

  @override
  Future<void> unloadModel() async {
    try {
      await ONNXRuntimes.channel.invokeMethod('unloadImageCaptionModel');
      _loaded = false;
      logger.info('Image Captioning model unloaded');
    } on PlatformException catch (e) {
      logger.error('Failed to unload Image Captioning model', e);
    }
  }

  @override
  Future<ImageCaptionResult> caption(
    String imagePath, {
    ImageCaptionParams? params,
  }) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      return await captionBytes(bytes, params: params);
    } catch (e) {
      logger.error('Image caption failed', e);
      rethrow;
    }
  }

  @override
  Future<ImageCaptionResult> captionBytes(
    Uint8List imageBytes, {
    ImageCaptionParams? params,
  }) async {
    try {
      final result = await ONNXRuntimes.channel.invokeMethod('captionImage', {
        'imageData': imageBytes,
        if (params?.maxLength != null) 'max_length': params!.maxLength,
        if (params?.temperature != null) 'temperature': params!.temperature,
        if (params?.numCandidates != null) 'num_candidates': params!.numCandidates,
      });

      if (result is Map) {
        return ImageCaptionResult.fromJson(Map<String, dynamic>.from(result));
      }

      throw Exception('Invalid Image Captioning result');
    } on PlatformException catch (e) {
      logger.error('Image caption failed', e);
      rethrow;
    }
  }
}
