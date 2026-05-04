import 'dart:typed_data';
import '../models/inference_result.dart';

/// Image Captioning 参数
class ImageCaptionParams {
  /// 最大生成长度
  final int? maxLength;

  /// 温度
  final double? temperature;

  /// 是否返回多个候选
  final int? numCandidates;

  const ImageCaptionParams({
    this.maxLength,
    this.temperature,
    this.numCandidates,
  });

  Map<String, dynamic> toJson() {
    return {
      if (maxLength != null) 'max_length': maxLength,
      if (temperature != null) 'temperature': temperature,
      if (numCandidates != null) 'num_candidates': numCandidates,
    };
  }
}

/// Image Captioning 配置
class ImageCaptionConfig {
  /// 模型文件路径
  final String modelPath;

  /// 额外配置
  final Map<String, dynamic>? config;

  const ImageCaptionConfig({
    required this.modelPath,
    this.config,
  });

  Map<String, dynamic> toJson() {
    return {
      'modelPath': modelPath,
      if (config != null) 'config': config,
    };
  }
}

/// Image Captioning 运行时接口
abstract class ImageCaptionRuntime {
  /// 加载模型
  Future<void> loadModel(ImageCaptionConfig config);

  /// 卸载模型
  Future<void> unloadModel();

  /// 生成图片描述
  Future<ImageCaptionResult> caption(
    String imagePath, {
    ImageCaptionParams? params,
  });

  /// 生成图片描述 (字节)
  Future<ImageCaptionResult> captionBytes(
    Uint8List imageBytes, {
    ImageCaptionParams? params,
  });

  /// 是否已加载
  bool get isLoaded;
}
