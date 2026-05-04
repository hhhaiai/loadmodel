import 'dart:typed_data';
import 'image_caption_runtime.dart';
import '../models/inference_result.dart';

/// Image Captioning Stub 实现
class ImageCaptionRuntimeStub implements ImageCaptionRuntime {
  @override
  bool get isLoaded => false;

  @override
  Future<void> loadModel(ImageCaptionConfig config) async {
    throw UnimplementedError('Image Captioning not available on this platform');
  }

  @override
  Future<void> unloadModel() async {}

  @override
  Future<ImageCaptionResult> caption(
    String imagePath, {
    ImageCaptionParams? params,
  }) async {
    throw UnimplementedError('Image Captioning not available on this platform');
  }

  @override
  Future<ImageCaptionResult> captionBytes(
    Uint8List imageBytes, {
    ImageCaptionParams? params,
  }) async {
    throw UnimplementedError('Image Captioning not available on this platform');
  }
}
