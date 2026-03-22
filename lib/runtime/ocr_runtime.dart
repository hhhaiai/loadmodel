import 'dart:typed_data';
import '../models/inference_result.dart';

/// OCR 参数
class OCRParams {
  /// 语言 (chi_sim, eng 等)
  final String? language;

  /// 是否检测文字方向
  final bool? detectDirection;

  /// 文字方向阈值
  final double? angleThreshold;

  const OCRParams({
    this.language,
    this.detectDirection,
    this.angleThreshold,
  });

  Map<String, dynamic> toJson() {
    return {
      if (language != null) 'language': language,
      if (detectDirection != null) 'detect_direction': detectDirection,
      if (angleThreshold != null) 'angle_threshold': angleThreshold,
    };
  }
}

/// OCR 配置
class OCRConfig {
  /// 模型文件路径
  final String modelPath;

  /// 语言
  final String language;

  /// 额外配置
  final Map<String, dynamic>? config;

  const OCRConfig({
    required this.modelPath,
    this.language = 'eng+chi_sim',
    this.config,
  });

  Map<String, dynamic> toJson() {
    return {
      'modelPath': modelPath,
      'language': language,
      'config': config,
    };
  }
}

/// OCR 运行时接口
abstract class OCRRuntime {
  /// 加载模型
  Future<void> loadModel(OCRConfig config);

  /// 卸载模型
  Future<void> unloadModel();

  /// 识别图片中的文字
  Future<OCRResult> recognize(
    String imagePath, {
    OCRParams? params,
  });

  /// 识别图片中的文字 (字节)
  Future<OCRResult> recognizeBytes(
    Uint8List imageBytes, {
    OCRParams? params,
  });

  /// 是否已加载
  bool get isLoaded;
}
