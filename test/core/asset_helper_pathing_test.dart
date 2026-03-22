import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/core/asset_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const assetsChannel = 'flutter/assets';
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  final testCacheDir = Directory.systemTemp.createTempSync('asset_helper_pathing_test_');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationCacheDirectory') {
        return testCacheDir.path;
      }
      return null;
    });

    final binding = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    binding.setMockMessageHandler(assetsChannel, (message) async {
      final key = const StringCodec().decodeMessage(message)!;
      switch (key) {
        case 'assets/models/whisper/model.onnx':
          final bytes = Uint8List.fromList([1, 2, 3]);
          return ByteData.view(bytes.buffer);
        case 'assets/models/ocr/model.onnx':
          final bytes = Uint8List.fromList([4, 5, 6]);
          return ByteData.view(bytes.buffer);
        default:
          return null;
      }
    });
  });

  tearDownAll(() async {
    final binding = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    binding.setMockMessageHandler(assetsChannel, null);
    binding.setMockMethodCallHandler(pathProviderChannel, null);
    if (testCacheDir.existsSync()) {
      testCacheDir.deleteSync(recursive: true);
    }
  });

  test('asset cache path preserves relative asset subdirectories', () async {
    final helper = AssetHelper();
    await helper.clearCache();

    final whisperPath = await helper.loadAssetToCache('assets/models/whisper/model.onnx');
    final ocrPath = await helper.loadAssetToCache('assets/models/ocr/model.onnx');

    final normalizedWhisperPath = whisperPath.replaceAll('\\', '/');
    final normalizedOcrPath = ocrPath.replaceAll('\\', '/');

    expect(normalizedWhisperPath, contains('/models/models/whisper/model.onnx'));
    expect(normalizedOcrPath, contains('/models/models/ocr/model.onnx'));
    expect(whisperPath, isNot(equals(ocrPath)));
  });
}
