import '../utils/logger.dart';
import 'core/platform_utils.dart';
import 'core/model_manager.dart';
import 'core/config_manager.dart';
import 'runtime/llm_runtime.dart';
import 'runtime/ocr_runtime.dart';
import 'runtime/tts_runtime.dart';
import 'runtime/stt_runtime.dart';
import 'runtime/embedding_runtime.dart';
import 'runtime/llm_runtime_stub.dart';
import 'runtime/ocr_runtime_stub.dart';
import 'runtime/tts_runtime_stub.dart';
import 'runtime/stt_runtime_stub.dart';
import 'runtime/embedding_runtime_stub.dart';
import 'runtime/runtime_factory.dart';
import 'models/model_type.dart';
import 'models/model_registry.dart';

/// ModelLoader 配置
class ModelLoaderConfig {
  /// 自定义模型路径
  final String? customModelPath;

  /// 模型缓存目录
  final String? modelCacheDir;

  /// 是否启用远程模型
  final bool enableRemoteModels;

  /// 远程模型列表地址
  final String? remoteModelListUrl;

  /// 日志级别
  final LogLevel logLevel;

  /// 是否自动选择最佳运行时
  final bool autoSelectRuntime;

  const ModelLoaderConfig({
    this.customModelPath,
    this.modelCacheDir,
    this.enableRemoteModels = true,
    this.remoteModelListUrl,
    this.logLevel = LogLevel.info,
    this.autoSelectRuntime = true,
  });

  /// 获取模型缓存目录
  String get cacheDir => modelCacheDir ?? PlatformUtils.getDefaultCacheDirSync();

  /// 获取自定义模型目录
  String get customDir => customModelPath ?? PlatformUtils.getDefaultCustomModelDirSync();
}

/// ModelLoader SDK 入口
class ModelLoader {
  static ModelLoader? _instance;

  late final ModelLoaderConfig _config;
  late final ModelManager _modelManager;
  late final ConfigManager _configManager;

  // 运行时
  late LLMRuntime _llm;
  late OCRRuntime _ocr;
  late TTSRuntime _tts;
  late STTRuntime _stt;
  late EmbeddingRuntime _embedding;

  // 平台信息
  late final PlatformInfo _platform;

  bool _initialized = false;

  ModelLoader._();

  /// 获取 SDK 实例
  static ModelLoader get instance {
    if (_instance == null) {
      throw StateError(
        'ModelLoader not initialized. Call ModelLoader.initialize() first.',
      );
    }
    return _instance!;
  }

  /// 是否已初始化
  bool get isInitialized => _initialized;

  /// 获取配置
  ModelLoaderConfig get config => _config;

  /// 获取平台信息
  PlatformInfo get platform => _platform;

  /// 模型管理
  ModelManager get models => _modelManager;

  /// 配置管理
  ConfigManager get configManager => _configManager;

  /// LLM 运行时
  LLMRuntime get llm => _llm;

  /// OCR 运行时
  OCRRuntime get ocr => _ocr;

  /// TTS 运行时
  TTSRuntime get tts => _tts;

  /// STT 运行时
  STTRuntime get stt => _stt;

  /// Embedding 运行时
  EmbeddingRuntime get embedding => _embedding;

  /// 初始化 SDK
  static Future<ModelLoader> initialize({
    ModelLoaderConfig? config,
  }) async {
    if (_instance != null && _instance!._initialized) {
      logger.warning('ModelLoader already initialized');
      return _instance!;
    }

    _instance = ModelLoader._();
    await _instance!._init(config);
    return _instance!;
  }

  Future<void> _init(ModelLoaderConfig? config) async {
    _config = config ?? const ModelLoaderConfig();

    // 设置日志级别
    Logger.setMinLevel(_config.logLevel);

    // 获取平台信息
    _platform = PlatformInfo.current();

    logger.info('ModelLoader initializing...');
    logger.info('Platform: ${_platform.name}');
    logger.info('Is Mobile: ${_platform.isMobile}');
    logger.info('Is Desktop: ${_platform.isDesktop}');
    logger.info('Cache directory: ${_config.cacheDir}');
    logger.info('Custom models directory: ${_config.customDir}');

    // 初始化配置管理器
    _configManager = ConfigManager(configDir: _config.cacheDir);
    await _configManager.init();

    // 初始化模型管理器
    _modelManager = ModelManager(
      cacheDir: _config.cacheDir,
      remoteModelListUrl: _config.remoteModelListUrl,
      enableRemoteModels: _config.enableRemoteModels,
    );
    await _modelManager.init();

    // 初始化运行时
    await _initRuntimes();

    _initialized = true;
    logger.info('ModelLoader initialized successfully');
  }

  /// 初始化运行时
  Future<void> _initRuntimes() async {
    // 默认使用 Stub
    _llm = LLMRuntimeStub();
    _ocr = OCRRuntimeStub();
    _tts = TTSRuntimeStub();
    _stt = STTRuntimeStub();
    _embedding = EmbeddingRuntimeStub();

    // 如果开启自动选择，尝试加载平台特定的运行时
    if (_config.autoSelectRuntime) {
      await _loadPlatformRuntimes();
    }

    logger.info('Runtimes initialized');
  }

  /// 加载平台特定的运行时
  Future<void> _loadPlatformRuntimes() async {
    try {
      if (_platform.isMobile) {
        await _initMobileRuntimes();
      } else if (_platform.isDesktop) {
        await _initDesktopRuntimes();
      }
    } catch (e) {
      logger.warning('Failed to load platform runtimes: $e');
    }
  }

  /// 初始化移动端运行时
  Future<void> _initMobileRuntimes() async {
    logger.info('Initializing mobile runtimes...');

    // 移动端使用 ONNX Runtime
    // 尝试加载 ONNX 运行时
    try {
      // 动态导入 - 需要运行时支持
      // final onnx = await import('./onnx_runtime_flutter.dart');
      // _ocr = onnx.ONNXRuntimes.ocr;
      // _stt = onnx.ONNXRuntimes.stt;
      // _embedding = onnx.ONNXRuntimes.embedding;

      logger.info('Mobile runtimes: Using ONNX (when available)');
    } catch (e) {
      logger.warning('ONNX runtime not available: $e');
    }
  }

  /// 初始化桌面端运行时
  Future<void> _initDesktopRuntimes() async {
    logger.info('Initializing desktop runtimes...');

    // 桌面端使用 llama.cpp + ONNX
    try {
      // 尝试加载 llama.cpp
      // final llama = await import('./llm_runtime_llama.cpp.dart');
      // _llm = llama.LLMRuntimeLlamaCpp();

      logger.info('Desktop runtimes: Using llama.cpp + ONNX (when available)');
    } catch (e) {
      logger.warning('llama.cpp not available: $e');
    }
  }

  /// 获取推荐运行时配置
  RuntimeConfig getRecommendedRuntime(ModelType type) {
    return RuntimeFactory.getBestConfig(_platform, type);
  }

  /// 获取支持的模型列表
  List<ModelDefinition> getSupportedModels() {
    return BuiltInModels.getSupportedForCurrentPlatform();
  }

  /// 按类型获取模型
  List<ModelDefinition> getModelsByType(ModelType type) {
    return BuiltInModels.getByType(type);
  }

  /// 替换 LLM 运行时实现
  void setLLMRuntime(LLMRuntime runtime) {
    _llm = runtime;
    logger.info('LLM runtime replaced');
  }

  /// 替换 OCR 运行时实现
  void setOCRRuntime(OCRRuntime runtime) {
    _ocr = runtime;
    logger.info('OCR runtime replaced');
  }

  /// 替换 TTS 运行时实现
  void setTTSRuntime(TTSRuntime runtime) {
    _tts = runtime;
    logger.info('TTS runtime replaced');
  }

  /// 替换 STT 运行时实现
  void setSTTRuntime(STTRuntime runtime) {
    _stt = runtime;
    logger.info('STT runtime replaced');
  }

  /// 替换 Embedding 运行时实现
  void setEmbeddingRuntime(EmbeddingRuntime runtime) {
    _embedding = runtime;
    logger.info('Embedding runtime replaced');
  }

  /// 释放资源
  Future<void> dispose() async {
    logger.info('ModelLoader disposing...');

    // 卸载所有模型
    try {
      if (_llm.isLoaded) await _llm.unloadModel();
    } catch (e) {}

    try {
      if (_ocr.isLoaded) await _ocr.unloadModel();
    } catch (e) {}

    try {
      if (_tts.isLoaded) await _tts.unloadModel();
    } catch (e) {}

    try {
      if (_stt.isLoaded) await _stt.unloadModel();
    } catch (e) {}

    try {
      if (_embedding.isLoaded) await _embedding.unloadModel();
    } catch (e) {}

    _initialized = false;
    logger.info('ModelLoader disposed');
  }
}
