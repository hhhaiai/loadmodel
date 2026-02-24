/// 模型类型枚举
enum ModelType {
  /// 对话模型
  llm,

  /// 向量模型
  embedding,

  /// OCR文字识别
  ocr,

  /// 文字转语音
  tts,

  /// 语音转文字
  stt,

  /// 分类模型
  classification,

  /// 自定义模型
  custom,
}

extension ModelTypeExtension on ModelType {
  String get displayName {
    switch (this) {
      case ModelType.llm:
        return '对话模型';
      case ModelType.embedding:
        return '向量模型';
      case ModelType.ocr:
        return 'OCR识别';
      case ModelType.tts:
        return '文字转语音';
      case ModelType.stt:
        return '语音转文字';
      case ModelType.classification:
        return '分类模型';
      case ModelType.custom:
        return '自定义模型';
    }
  }

  String get name {
    switch (this) {
      case ModelType.llm:
        return 'llm';
      case ModelType.embedding:
        return 'embedding';
      case ModelType.ocr:
        return 'ocr';
      case ModelType.tts:
        return 'tts';
      case ModelType.stt:
        return 'stt';
      case ModelType.classification:
        return 'classification';
      case ModelType.custom:
        return 'custom';
    }
  }

  static ModelType fromString(String value) {
    return ModelType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ModelType.custom,
    );
  }
}
