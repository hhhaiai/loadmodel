import 'dart:typed_data';
import '../models/inference_result.dart';
import 'stt_runtime.dart';

/// STT 运行时默认实现 (Stub)
class STTRuntimeStub implements STTRuntime {
  @override
  bool get isLoaded => false;

  @override
  Future<void> loadModel(STTConfig config) async {
    throw UnimplementedError(
      'STT runtime not implemented. Please use a platform-specific implementation.',
    );
  }

  @override
  Future<void> unloadModel() async {
    // Stub
  }

  @override
  Future<STTResult> recognize(
    String audioPath, {
    STTParams? params,
  }) async {
    throw UnimplementedError('STT runtime not implemented');
  }

  @override
  Future<STTResult> recognizeBytes(
    Uint8List audioBytes, {
    STTParams? params,
  }) async {
    throw UnimplementedError('STT runtime not implemented');
  }

  @override
  Stream<STTResult> recognizeStream(
    Stream<Uint8List> audioStream, {
    STTParams? params,
  }) async* {
    throw UnimplementedError('STT runtime not implemented');
  }

  @override
  Future<List<String>> getSupportedLanguages() async {
    return [];
  }
}
