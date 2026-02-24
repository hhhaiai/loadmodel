/// 跨平台运行时工厂
import '../core/platform_utils.dart';
import '../models/model_type.dart';

/// 运行时配置
class RuntimeConfig {
  /// 运行时类型
  final String runtime;

  /// 优先级 (越高越推荐)
  final int priority;

  /// 描述
  final String description;

  const RuntimeConfig({
    required this.runtime,
    required this.priority,
    required this.description,
  });
}

/// 平台信息
class PlatformInfo {
  final String name;
  final bool isMobile;
  final bool isDesktop;
  final bool isIOS;
  final bool isAndroid;
  final bool isMacOS;
  final bool isWindows;
  final bool isLinux;

  const PlatformInfo({
    required this.name,
    required this.isMobile,
    required this.isDesktop,
    required this.isIOS,
    required this.isAndroid,
    required this.isMacOS,
    required this.isWindows,
    required this.isLinux,
  });

  factory PlatformInfo.current() {
    return PlatformInfo(
      name: PlatformUtils.platformName,
      isMobile: PlatformUtils.isMobile,
      isDesktop: PlatformUtils.isDesktop,
      isIOS: PlatformUtils.isIOS,
      isAndroid: PlatformUtils.isAndroid,
      isMacOS: PlatformUtils.isMacOS,
      isWindows: PlatformUtils.isWindows,
      isLinux: PlatformUtils.isLinux,
    );
  }
}

/// 跨平台运行时工厂
class RuntimeFactory {
  /// 获取最佳运行时配置
  static RuntimeConfig getBestConfig(PlatformInfo platform, ModelType modelType) {
    switch (modelType) {
      case ModelType.llm:
        return _getLLMRuntimeConfig(platform);
      case ModelType.embedding:
        return _getEmbeddingRuntimeConfig(platform);
      case ModelType.stt:
        return _getSTTRuntimeConfig(platform);
      case ModelType.tts:
        return _getTTSRuntimeConfig(platform);
      case ModelType.ocr:
        return _getOCRRuntimeConfig(platform);
      case ModelType.classification:
        return _getClassificationRuntimeConfig(platform);
      case ModelType.custom:
        return const RuntimeConfig(
          runtime: 'onnx',
          priority: 1,
          description: 'Custom model - use ONNX',
        );
    }
  }

  static RuntimeConfig _getLLMRuntimeConfig(PlatformInfo platform) {
    if (platform.isDesktop) {
      return const RuntimeConfig(
        runtime: 'llama.cpp',
        priority: 1,
        description: 'LLM: Use llama.cpp for best performance',
      );
    } else if (platform.isMobile) {
      return const RuntimeConfig(
        runtime: 'llama.cpp',
        priority: 1,
        description: 'LLM: Use quantized GGUF models (Q4-Q5)',
      );
    }
    return const RuntimeConfig(
      runtime: 'onnx',
      priority: 0,
      description: 'LLM: Limited support',
    );
  }

  static RuntimeConfig _getEmbeddingRuntimeConfig(PlatformInfo platform) {
    return const RuntimeConfig(
      runtime: 'onnx',
      priority: 1,
      description: 'Embedding: Use ONNX Runtime',
    );
  }

  static RuntimeConfig _getSTTRuntimeConfig(PlatformInfo platform) {
    return const RuntimeConfig(
      runtime: 'onnx',
      priority: 1,
      description: 'STT: Use ONNX Runtime (Whisper/SenseVoice)',
    );
  }

  static RuntimeConfig _getTTSRuntimeConfig(PlatformInfo platform) {
    return const RuntimeConfig(
      runtime: 'onnx',
      priority: 1,
      description: 'TTS: Use ONNX (Piper/CosyVoice)',
    );
  }

  static RuntimeConfig _getOCRRuntimeConfig(PlatformInfo platform) {
    return const RuntimeConfig(
      runtime: 'onnx',
      priority: 1,
      description: 'OCR: Use ONNX Runtime (EasyOCR)',
    );
  }

  static RuntimeConfig _getClassificationRuntimeConfig(PlatformInfo platform) {
    return const RuntimeConfig(
      runtime: 'onnx',
      priority: 1,
      description: 'Classification: Use ONNX or TFLite',
    );
  }
}
