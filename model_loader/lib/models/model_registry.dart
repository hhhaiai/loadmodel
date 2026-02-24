/// 模型运行时类型
import '../core/platform_utils.dart';
import '../runtime/runtime_factory.dart';
import 'model_type.dart';

enum RuntimeType {
  /// ONNX Runtime (跨平台)
  onnx,

  /// llama.cpp (桌面端)
  llamaCpp,

  /// TensorFlow Lite (移动端)
  tflite,

  /// MediaPipe (跨平台)
  mediaPipe,

  /// Vosk (语音识别)
  vosk,

  /// Whisper.cpp
  whisperCpp,
}

/// 模型能力
class ModelCapability {
  /// 支持的运行时
  final List<RuntimeType> supportedRuntimes;

  /// 是否支持量化
  final bool supportsQuantization;

  /// 最低内存要求 (MB)
  final int minMemoryMB;

  /// 推荐内存 (MB)
  final int recommendedMemoryMB;

  const ModelCapability({
    required this.supportedRuntimes,
    this.supportsQuantization = false,
    this.minMemoryMB = 512,
    this.recommendedMemoryMB = 1024,
  });
}

/// 模型类型定义
class ModelDefinition {
  /// 模型ID
  final String id;

  /// 显示名称
  final String name;

  /// 模型类型
  final ModelType type;

  /// 支持的格式
  final List<String> formats;

  /// 能力
  final ModelCapability capability;

  /// 默认配置
  final Map<String, dynamic>? defaultConfig;

  const ModelDefinition({
    required this.id,
    required this.name,
    required this.type,
    required this.formats,
    required this.capability,
    this.defaultConfig,
  });
}

/// 内置模型定义
class BuiltInModels {
  static const Map<String, ModelDefinition> models = {
    // Embedding 模型
    'bge-small-zh': ModelDefinition(
      id: 'bge-small-zh',
      name: 'BGE Small ZH',
      type: ModelType.embedding,
      formats: ['onnx', 'tflite'],
      capability: ModelCapability(
        supportedRuntimes: [RuntimeType.onnx, RuntimeType.tflite],
        minMemoryMB: 256,
        recommendedMemoryMB: 512,
      ),
    ),
    'bge-small-en': ModelDefinition(
      id: 'bge-small-en',
      name: 'BGE Small EN',
      type: ModelType.embedding,
      formats: ['onnx', 'tflite'],
      capability: ModelCapability(
        supportedRuntimes: [RuntimeType.onnx, RuntimeType.tflite],
        minMemoryMB: 256,
        recommendedMemoryMB: 512,
      ),
    ),

    // STT 模型
    'sensevoice': ModelDefinition(
      id: 'sensevoice',
      name: 'SenseVoice',
      type: ModelType.stt,
      formats: ['onnx'],
      capability: ModelCapability(
        supportedRuntimes: [RuntimeType.onnx],
        minMemoryMB: 512,
        recommendedMemoryMB: 1024,
      ),
    ),
    'whisper-tiny': ModelDefinition(
      id: 'whisper-tiny',
      name: 'Whisper Tiny',
      type: ModelType.stt,
      formats: ['onnx', 'bin'],
      capability: ModelCapability(
        supportedRuntimes: [RuntimeType.onnx, RuntimeType.whisperCpp],
        minMemoryMB: 256,
        recommendedMemoryMB: 512,
      ),
    ),
    'vosk-cn': ModelDefinition(
      id: 'vosk-cn',
      name: 'Vosk Chinese',
      type: ModelType.stt,
      formats: ['vosk'],
      capability: ModelCapability(
        supportedRuntimes: [RuntimeType.vosk],
        minMemoryMB: 200,
        recommendedMemoryMB: 400,
      ),
    ),
    'vosk-en': ModelDefinition(
      id: 'vosk-en',
      name: 'Vosk English',
      type: ModelType.stt,
      formats: ['vosk'],
      capability: ModelCapability(
        supportedRuntimes: [RuntimeType.vosk],
        minMemoryMB: 150,
        recommendedMemoryMB: 300,
      ),
    ),

    // TTS 模型
    'cosyvoice': ModelDefinition(
      id: 'cosyvoice',
      name: 'CosyVoice',
      type: ModelType.tts,
      formats: ['onnx'],
      capability: ModelCapability(
        supportedRuntimes: [RuntimeType.onnx],
        minMemoryMB: 512,
        recommendedMemoryMB: 1024,
      ),
    ),
    'piper': ModelDefinition(
      id: 'piper',
      name: 'Piper TTS',
      type: ModelType.tts,
      formats: ['onnx'],
      capability: ModelCapability(
        supportedRuntimes: [RuntimeType.onnx],
        minMemoryMB: 300,
        recommendedMemoryMB: 512,
      ),
    ),

    // LLM 模型
    'qwen-0.5b': ModelDefinition(
      id: 'qwen-0.5b',
      name: 'Qwen 0.5B',
      type: ModelType.llm,
      formats: ['gguf', 'onnx'],
      capability: ModelCapability(
        supportedRuntimes: [RuntimeType.llamaCpp, RuntimeType.onnx],
        supportsQuantization: true,
        minMemoryMB: 2048,
        recommendedMemoryMB: 4096,
      ),
    ),
    'tinyllama': ModelDefinition(
      id: 'tinyllama',
      name: 'TinyLlama 1.1B',
      type: ModelType.llm,
      formats: ['gguf'],
      capability: ModelCapability(
        supportedRuntimes: [RuntimeType.llamaCpp],
        supportsQuantization: true,
        minMemoryMB: 2048,
        recommendedMemoryMB: 4096,
      ),
    ),
    'llama3-8b': ModelDefinition(
      id: 'llama3-8b',
      name: 'Llama 3 8B',
      type: ModelType.llm,
      formats: ['gguf'],
      capability: ModelCapability(
        supportedRuntimes: [RuntimeType.llamaCpp],
        supportsQuantization: true,
        minMemoryMB: 8192,
        recommendedMemoryMB: 16384,
      ),
    ),

    // OCR 模型
    'easyocr': ModelDefinition(
      id: 'easyocr',
      name: 'EasyOCR',
      type: ModelType.ocr,
      formats: ['onnx', 'tflite'],
      capability: ModelCapability(
        supportedRuntimes: [RuntimeType.onnx, RuntimeType.tflite],
        minMemoryMB: 512,
        recommendedMemoryMB: 1024,
      ),
    ),
  };

  /// 获取所有模型
  static List<ModelDefinition> getAllModels() => models.values.toList();

  /// 按类型获取模型
  static List<ModelDefinition> getByType(ModelType type) {
    return models.values.where((m) => m.type == type).toList();
  }

  /// 按ID获取模型
  static ModelDefinition? getById(String id) => models[id];

  /// 获取支持当前平台的模型
  static List<ModelDefinition> getSupportedForCurrentPlatform() {
    final platform = PlatformUtils.platformName;
    return models.values
        .where((m) => m.capability.supportedRuntimes.isNotEmpty)
        .toList();
  }
}
