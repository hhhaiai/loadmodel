import 'dart:typed_data';
import 'tts_runtime.dart';

/// TTS 运行时默认实现 (Stub)
class TTSRuntimeStub implements TTSRuntime {
  @override
  bool get isLoaded => false;

  @override
  Future<void> loadModel(TTSConfig config) async {
    throw UnimplementedError(
      'TTS runtime not implemented. Please use a platform-specific implementation.',
    );
  }

  @override
  Future<void> unloadModel() async {
    // Stub
  }

  @override
  Future<String> synthesize(
    String text, {
    TTSParams? params,
    String? outputPath,
  }) async {
    throw UnimplementedError('TTS runtime not implemented');
  }

  @override
  Future<Uint8List> synthesizeBytes(
    String text, {
    TTSParams? params,
  }) async {
    throw UnimplementedError('TTS runtime not implemented');
  }

  @override
  Future<List<String>> getAvailableVoices() async {
    return [];
  }
}
