import 'embedding_runtime.dart';

/// Embedding 运行时默认实现 (Stub)
class EmbeddingRuntimeStub implements EmbeddingRuntime {
  @override
  bool get isLoaded => false;

  @override
  Future<void> loadModel(EmbeddingConfig config) async {
    throw UnimplementedError(
      'Embedding runtime not implemented. Please use a platform-specific implementation.',
    );
  }

  @override
  Future<void> unloadModel() async {
    // Stub
  }

  @override
  Future<EmbeddingResult> getEmbedding(String text) async {
    throw UnimplementedError('Embedding runtime not implemented');
  }
}
