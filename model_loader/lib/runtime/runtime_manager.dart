import '../core/platform_utils.dart';
import '../utils/logger.dart';
import 'llm_runtime.dart';
import 'ocr_runtime.dart';
import 'tts_runtime.dart';
import 'stt_runtime.dart';
import 'embedding_runtime.dart';

/// 统一运行时管理器
/// 根据平台自动选择最合适的运行时实现
class RuntimeManager {
  static RuntimeManager? _instance;

  late final LLMRuntime llm;
  late final OCRRuntime ocr;
  late final TTSRuntime tts;
  late final STTRuntime stt;
  late final EmbeddingRuntime embedding;

  bool _initialized = false;

  RuntimeManager._();

  static RuntimeManager get instance {
    _instance ??= RuntimeManager._();
    return _instance!;
  }

  /// 初始化运行时
  Future<void> init({
    LLMRuntime? customLLM,
    OCRRuntime? customOCR,
    TTSRuntime? customTTS,
    STTRuntime? customSTT,
    EmbeddingRuntime? customEmbedding,
  }) async {
    if (_initialized) {
      logger.warning('RuntimeManager already initialized');
      return;
    }

    logger.info('Initializing RuntimeManager for ${PlatformUtils.platformName}...');

    // 移动端使用 ONNX
    if (PlatformUtils.isMobile) {
      await _initMobileRuntimes(
        customLLM: customLLM,
        customOCR: customOCR,
        customTTS: customTTS,
        customSTT: customSTT,
        customEmbedding: customEmbedding,
      );
    }
    // 桌面端使用 llama.cpp + ONNX
    else if (PlatformUtils.isDesktop) {
      await _initDesktopRuntimes(
        customLLM: customLLM,
        customOCR: customOCR,
        customTTS: customTTS,
        customSTT: customSTT,
        customEmbedding: customEmbedding,
      );
    }

    _initialized = true;
    logger.info('RuntimeManager initialized');
  }

  Future<void> _initMobileRuntimes({
    LLMRuntime? customLLM,
    OCRRuntime? customOCR,
    TTSRuntime? customTTS,
    STTRuntime? customSTT,
    EmbeddingRuntime? customEmbedding,
  }) async {
    // 移动端使用 ONNX Runtime
    // 尝试导入 ONNX 运行时，如果失败则使用 Stub
    try {
      // 动态导入 ONNX 运行时
      // final onnx = await import('package:model_loader/runtime/onnx_runtime_flutter.dart');

      // 使用传入的自定义运行时或默认 Stub
      llm = customLLM ?? _createStubLLM();
      ocr = customOCR ?? _createStubOCR();
      tts = customTTS ?? _createStubTTS();
      stt = customSTT ?? _createStubSTT();
      embedding = customEmbedding ?? _createStubEmbedding();
    } catch (e) {
      logger.error('Failed to initialize mobile runtimes', e);
      rethrow;
    }
  }

  Future<void> _initDesktopRuntimes({
    LLMRuntime? customLLM,
    OCRRuntime? customOCR,
    TTSRuntime? customTTS,
    STTRuntime? customSTT,
    EmbeddingRuntime? customEmbedding,
  }) async {
    // 桌面端优先使用 llama.cpp for LLM
    // ONNX for Embedding/STT/OCR

    // 尝试加载 llama.cpp
    try {
      // final llama = await _loadLlamaCpp();
      // llm = customLLM ?? llama;
    } catch (e) {
      logger.warning('llama.cpp not available, using stub LLM');
    }

    llm = customLLM ?? _createStubLLM();
    ocr = customOCR ?? _createStubOCR();
    tts = customTTS ?? _createStubTTS();
    stt = customSTT ?? _createStubSTT();
    embedding = customEmbedding ?? _createStubEmbedding();
  }

  /// 释放所有运行时
  Future<void> dispose() async {
    logger.info('Disposing RuntimeManager...');

    try {
      if (llm.isLoaded) await llm.unloadModel();
    } catch (e) {
      logger.warning('Error unloading LLM: $e');
    }

    try {
      if (ocr.isLoaded) await ocr.unloadModel();
    } catch (e) {
      logger.warning('Error unloading OCR: $e');
    }

    try {
      if (tts.isLoaded) await tts.unloadModel();
    } catch (e) {
      logger.warning('Error unloading TTS: $e');
    }

    try {
      if (stt.isLoaded) await stt.unloadModel();
    } catch (e) {
      logger.warning('Error unloading STT: $e');
    }

    try {
      if (embedding.isLoaded) await embedding.unloadModel();
    } catch (e) {
      logger.warning('Error unloading Embedding: $e');
    }

    _initialized = false;
    logger.info('RuntimeManager disposed');
  }

  // 创建 Stub 实现
  LLMRuntime _createStubLLM() => _LLMRuntimeStub();
  OCRRuntime _createStubOCR() => _OCRRuntimeStub();
  TTSRuntime _createStubTTS() => _TTSRuntimeStub();
  STTRuntime _createStubSTT() => _STTRuntimeStub();
  EmbeddingRuntime _createStubEmbedding() => _EmbeddingRuntimeStub();
}

// Stub 实现
class _LLMRuntimeStub implements LLMRuntime {
  @override
  LLMModelInfo? get loadedModel => null;
  @override
  bool get isLoaded => false;
  @override
  Future<void> loadModel(LLMConfig config) async => throw UnimplementedError('LLM not available on this platform');
  @override
  Future<void> unloadModel() async {}
  @override
  Future<String> complete(String prompt, {GenerationConfig? config}) async => throw UnimplementedError();
  @override
  Stream<String> completeStream(String prompt, {GenerationConfig? config}) async* => throw UnimplementedError();
  @override
  Future<String> chat(List<ChatMessage> messages, {GenerationConfig? config}) async => throw UnimplementedError();
  @override
  Stream<String> chatStream(List<ChatMessage> messages, {GenerationConfig? config}) async* => throw UnimplementedError();
}

class _OCRRuntimeStub implements OCRRuntime {
  @override
  bool get isLoaded => false;
  @override
  Future<void> loadModel(OCRConfig config) async => throw UnimplementedError('OCR not available on this platform');
  @override
  Future<void> unloadModel() async {}
  @override
  Future<OCRResult> recognize(String imagePath, {OCRParams? params}) async => throw UnimplementedError();
  @override
  Future<OCRResult> recognizeBytes(Uint8List imageBytes, {OCRParams? params}) async => throw UnimplementedError();
}

class _TTSRuntimeStub implements TTSRuntime {
  @override
  bool get isLoaded => false;
  @override
  Future<void> loadModel(TTSConfig config) async => throw UnimplementedError('TTS not available on this platform');
  @override
  Future<void> unloadModel() async {}
  @override
  Future<String> synthesize(String text, {TTSParams? params, String? outputPath}) async => throw UnimplementedError();
  @override
  Future<Uint8List> synthesizeBytes(String text, {TTSParams? params}) async => throw UnimplementedError();
  @override
  Future<List<String>> getAvailableVoices() async => [];
}

class _STTRuntimeStub implements STTRuntime {
  @override
  bool get isLoaded => false;
  @override
  Future<void> loadModel(STTConfig config) async => throw UnimplementedError('STT not available on this platform');
  @override
  Future<void> unloadModel() async {}
  @override
  Future<STTResult> recognize(String audioPath, {STTParams? params}) async => throw UnimplementedError();
  @override
  Future<STTResult> recognizeBytes(Uint8List audioBytes, {STTParams? params}) async => throw UnimplementedError();
  @override
  Stream<STTResult> recognizeStream(Stream<Uint8List> audioStream, {STTParams? params}) async* => throw UnimplementedError();
  @override
  Future<List<String>> getSupportedLanguages() async => [];
}

class _EmbeddingRuntimeStub implements EmbeddingRuntime {
  @override
  bool get isLoaded => false;
  @override
  Future<void> loadModel(EmbeddingConfig config) async => throw UnimplementedError('Embedding not available on this platform');
  @override
  Future<void> unloadModel() async {}
  @override
  Future<EmbeddingResult> getEmbedding(String text) async => throw UnimplementedError();
}
