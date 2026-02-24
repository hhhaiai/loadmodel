import 'dart:typed_data';
import '../models/inference_result.dart';
import 'ocr_runtime.dart';

/// OCR 运行时默认实现 (Stub)
class OCRRuntimeStub implements OCRRuntime {
  @override
  bool get isLoaded => false;

  @override
  Future<void> loadModel(OCRConfig config) async {
    throw UnimplementedError(
      'OCR runtime not implemented. Please use a platform-specific implementation.',
    );
  }

  @override
  Future<void> unloadModel() async {
    // Stub
  }

  @override
  Future<OCRResult> recognize(
    String imagePath, {
    OCRParams? params,
  }) async {
    throw UnimplementedError('OCR runtime not implemented');
  }

  @override
  Future<OCRResult> recognizeBytes(
    Uint8List imageBytes, {
    OCRParams? params,
  }) async {
    throw UnimplementedError('OCR runtime not implemented');
  }
}
