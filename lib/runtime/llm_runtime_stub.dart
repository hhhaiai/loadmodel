import 'llm_runtime.dart';

/// LLM 运行时默认实现 (Stub)
class LLMRuntimeStub implements LLMRuntime {
  @override
  LLMModelInfo? get loadedModel => null;

  @override
  bool get isLoaded => false;

  @override
  Future<void> loadModel(LLMConfig config) async {
    throw UnimplementedError(
      'LLM runtime not implemented. Please use a platform-specific implementation.',
    );
  }

  @override
  Future<void> unloadModel() async {
    // Stub
  }

  @override
  Future<String> complete(
    String prompt, {
    GenerationConfig? config,
  }) async {
    throw UnimplementedError('LLM runtime not implemented');
  }

  @override
  Stream<String> completeStream(
    String prompt, {
    GenerationConfig? config,
  }) async* {
    throw UnimplementedError('LLM runtime not implemented');
  }

  @override
  Future<String> chat(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  }) async {
    throw UnimplementedError('LLM runtime not implemented');
  }

  @override
  Stream<String> chatStream(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  }) async* {
    throw UnimplementedError('LLM runtime not implemented');
  }
}
