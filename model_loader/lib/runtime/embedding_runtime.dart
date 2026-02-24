/// Embedding 配置
class EmbeddingConfig {
  final String modelPath;
  final String? tokenizerPath;
  final int maxLength;

  const EmbeddingConfig({
    required this.modelPath,
    this.tokenizerPath,
    this.maxLength = 512,
  });

  Map<String, dynamic> toJson() {
    return {
      'modelPath': modelPath,
      'tokenizerPath': tokenizerPath,
      'maxLength': maxLength,
    };
  }
}

/// Embedding 结果
class EmbeddingResult {
  final List<double> embedding;
  final int dimension;

  const EmbeddingResult({
    required this.embedding,
    required this.dimension,
  });

  factory EmbeddingResult.fromJson(Map<String, dynamic> json) {
    return EmbeddingResult(
      embedding: (json['embedding'] as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
      dimension: json['dimension'] ?? (json['embedding'] as List?)?.length ?? 0,
    );
  }
}

/// Embedding 运行时接口
abstract class EmbeddingRuntime {
  Future<void> loadModel(EmbeddingConfig config);
  Future<void> unloadModel();
  Future<EmbeddingResult> getEmbedding(String text);
  bool get isLoaded;
}
