import 'dart:typed_data';
import '../models/inference_result.dart';

/// STT 参数
class STTParams {
  /// 语言
  final String? language;

  /// 是否翻译
  final bool? translate;

  /// 是否生成时间戳
  final bool? timestamps;

  /// 是否识别多语言
  final bool? multilingual;

  /// 音频块大小
  final int? chunkSize;

  const STTParams({
    this.language,
    this.translate,
    this.timestamps,
    this.multilingual,
    this.chunkSize,
  });

  Map<String, dynamic> toJson() {
    return {
      if (language != null) 'language': language,
      if (translate != null) 'translate': translate,
      if (timestamps != null) 'timestamps': timestamps,
      if (multilingual != null) 'multilingual': multilingual,
      if (chunkSize != null) 'chunk_size': chunkSize,
    };
  }
}

/// STT 配置
class STTConfig {
  /// 模型文件路径
  final String modelPath;

  /// 语言
  final String language;

  /// 采样率
  final int sampleRate;

  /// 额外配置
  final Map<String, dynamic>? config;

  const STTConfig({
    required this.modelPath,
    this.language = 'auto',
    this.sampleRate = 16000,
    this.config,
  });

  Map<String, dynamic> toJson() {
    return {
      'modelPath': modelPath,
      'language': language,
      'sampleRate': sampleRate,
      'config': config,
    };
  }
}

/// STT 运行时接口
abstract class STTRuntime {
  /// 加载模型
  Future<void> loadModel(STTConfig config);

  /// 卸载模型
  Future<void> unloadModel();

  /// 语音转文字 (文件)
  Future<STTResult> recognize(
    String audioPath, {
    STTParams? params,
  });

  /// 语音转文字 (字节)
  Future<STTResult> recognizeBytes(
    Uint8List audioBytes, {
    STTParams? params,
  });

  /// 流式识别
  Stream<STTResult> recognizeStream(
    Stream<Uint8List> audioStream, {
    STTParams? params,
  });

  /// 获取支持的语言
  Future<List<String>> getSupportedLanguages();

  /// 是否已加载
  bool get isLoaded;
}
