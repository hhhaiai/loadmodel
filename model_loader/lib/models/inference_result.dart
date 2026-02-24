/// OCR 文字块
class OCRBlock {
  /// 文字内容
  final String text;

  /// 置信度 (0.0 - 1.0)
  final double confidence;

  /// 文字位置 (left, top, width, height)
  final Rect? boundingBox;

  const OCRBlock({
    required this.text,
    this.confidence = 1.0,
    this.boundingBox,
  });

  factory OCRBlock.fromJson(Map<String, dynamic> json) {
    return OCRBlock(
      text: json['text'] ?? '',
      confidence: (json['confidence'] ?? 1.0).toDouble(),
      boundingBox: json['bbox'] != null
          ? Rect.fromJson(json['bbox'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'confidence': confidence,
      'bbox': boundingBox?.toJson(),
    };
  }
}

/// 矩形区域
class Rect {
  final double left;
  final double top;
  final double width;
  final double height;

  const Rect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  factory Rect.fromJson(Map<String, dynamic> json) {
    return Rect(
      left: (json['left'] ?? 0).toDouble(),
      top: (json['top'] ?? 0).toDouble(),
      width: (json['width'] ?? 0).toDouble(),
      height: (json['height'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'left': left,
      'top': top,
      'width': width,
      'height': height,
    };
  }
}

/// OCR 结果
class OCRResult {
  /// 识别出的完整文本
  final String text;

  /// 文字块列表
  final List<OCRBlock> blocks;

  /// 平均置信度
  final double averageConfidence;

  const OCRResult({
    required this.text,
    required this.blocks,
    this.averageConfidence = 1.0,
  });

  factory OCRResult.fromJson(Map<String, dynamic> json) {
    final blocksList = (json['blocks'] as List<dynamic>?)
            ?.map((e) => OCRBlock.fromJson(e))
            .toList() ??
        [];

    return OCRResult(
      text: json['text'] ?? '',
      blocks: blocksList,
      averageConfidence: (json['averageConfidence'] ?? 1.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'blocks': blocks.map((e) => e.toJson()).toList(),
      'averageConfidence': averageConfidence,
    };
  }
}

/// STT 语音识别结果
class STTResult {
  /// 识别出的文本
  final String text;

  /// 片段列表
  final List<STTSegment> segments;

  /// 语言
  final String? language;

  /// 置信度
  final double confidence;

  const STTResult({
    required this.text,
    this.segments = const [],
    this.language,
    this.confidence = 1.0,
  });

  factory STTResult.fromJson(Map<String, dynamic> json) {
    final segmentsList = (json['segments'] as List<dynamic>?)
            ?.map((e) => STTSegment.fromJson(e))
            .toList() ??
        [];

    return STTResult(
      text: json['text'] ?? '',
      segments: segmentsList,
      language: json['language'],
      confidence: (json['confidence'] ?? 1.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'segments': segments.map((e) => e.toJson()).toList(),
      'language': language,
      'confidence': confidence,
    };
  }
}

/// STT 片段
class STTSegment {
  /// 开始时间 (秒)
  final double start;

  /// 结束时间 (秒)
  final double end;

  /// 文本
  final String text;

  /// 置信度
  final double confidence;

  const STTSegment({
    required this.start,
    required this.end,
    required this.text,
    this.confidence = 1.0,
  });

  factory STTSegment.fromJson(Map<String, dynamic> json) {
    return STTSegment(
      start: (json['start'] ?? 0).toDouble(),
      end: (json['end'] ?? 0).toDouble(),
      text: json['text'] ?? '',
      confidence: (json['confidence'] ?? 1.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
      'text': text,
      'confidence': confidence,
    };
  }
}

/// TTS 合成结果
class TTSResult {
  /// 音频文件路径
  final String? audioPath;

  /// 音频数据
  final List<int>? audioBytes;

  /// 时长 (秒)
  final double duration;

  /// 采样率
  final int sampleRate;

  const TTSResult({
    this.audioPath,
    this.audioBytes,
    this.duration = 0.0,
    this.sampleRate = 16000,
  });
}
