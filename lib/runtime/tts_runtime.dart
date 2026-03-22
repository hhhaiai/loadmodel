import 'dart:typed_data';

/// TTS 参数
class TTSParams {
  /// 语速
  final double? speed;

  /// 音调
  final double? pitch;

  /// 音量
  final double? volume;

  /// 语音风格
  final String? voice;

  /// 输出格式 (wav, mp3, ogg)
  final String? format;

  const TTSParams({
    this.speed,
    this.pitch,
    this.volume,
    this.voice,
    this.format,
  });

  Map<String, dynamic> toJson() {
    return {
      if (speed != null) 'speed': speed,
      if (pitch != null) 'pitch': pitch,
      if (volume != null) 'volume': volume,
      if (voice != null) 'voice': voice,
      if (format != null) 'format': format,
    };
  }
}

/// TTS 配置
class TTSConfig {
  /// 模型文件路径
  final String modelPath;

  /// 默认语言
  final String? language;

  /// 采样率
  final int sampleRate;

  /// 额外配置
  final Map<String, dynamic>? config;

  const TTSConfig({
    required this.modelPath,
    this.language,
    this.sampleRate = 22050,
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

/// TTS 运行时接口
abstract class TTSRuntime {
  /// 加载模型
  Future<void> loadModel(TTSConfig config);

  /// 卸载模型
  Future<void> unloadModel();

  /// 文字转语音 (保存到文件)
  Future<String> synthesize(
    String text, {
    TTSParams? params,
    String? outputPath,
  });

  /// 文字转语音 (返回音频数据)
  Future<Uint8List> synthesizeBytes(
    String text, {
    TTSParams? params,
  });

  /// 获取可用语音列表
  Future<List<String>> getAvailableVoices();

  /// 是否已加载
  bool get isLoaded;
}
