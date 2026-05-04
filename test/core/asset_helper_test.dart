import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/core/asset_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const assetsChannel = 'flutter/assets';
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  const runtimeChannel = MethodChannel('com.modelloader/model_runtime');

  late Directory testCacheDir;
  late AssetHelper helper;

  // Track runtime channel calls for verification
  final runtimeCalls = <MethodCall>[];

  setUpAll(() async {
    testCacheDir = Directory.systemTemp.createTempSync('asset_helper_test_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationCacheDirectory') {
        return testCacheDir.path;
      }
      return null;
    });
  });

  setUp(() async {
    helper = AssetHelper();
    await helper.clearCache();
    runtimeCalls.clear();

    // Default: mock rootBundle to return small test bytes for known assets
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(assetsChannel, (message) async {
      final key = const StringCodec().decodeMessage(message)!;
      switch (key) {
        case 'assets/models/testdir/model.bin':
          return ByteData.view(Uint8List.fromList([10, 20, 30]).buffer);
        case 'assets/models/testdir/tokenizer.json':
          return ByteData.view(Uint8List.fromList([40, 50, 60]).buffer);
        case 'assets/models/testdir/custom_name.bin':
          return ByteData.view(Uint8List.fromList([70, 80, 90]).buffer);
        case 'assets/models/embed/model.onnx':
          return ByteData.view(Uint8List.fromList([1, 2, 3]).buffer);
        default:
          return null;
      }
    });

    // Default: runtime channel returns null (no native preparation)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(runtimeChannel, (call) async {
      runtimeCalls.add(call);
      return null;
    });
  });

  tearDown(() async {
    // Clean up any files created in the models subdirectory
    final modelsDir = Directory('${testCacheDir.path}/models');
    if (modelsDir.existsSync()) {
      modelsDir.deleteSync(recursive: true);
    }
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(assetsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(runtimeChannel, null);
    if (testCacheDir.existsSync()) {
      testCacheDir.deleteSync(recursive: true);
    }
  });

  // ---------------------------------------------------------------------------
  // _buildCacheTargetPath (tested indirectly via loadAssetToCache)
  // ---------------------------------------------------------------------------

  group('_buildCacheTargetPath via loadAssetToCache', () {
    test('without filename strips assets/ prefix and preserves subdirectories',
        () async {
      final result =
          await helper.loadAssetToCache('assets/models/testdir/model.bin');
      final normalized = result.replaceAll('\\', '/');
      // Should strip 'assets/' then join with models dir: .../models/models/testdir/model.bin
      expect(normalized, contains('/models/models/testdir/model.bin'));
    });

    test('with filename uses filename instead of asset path', () async {
      final result = await helper.loadAssetToCache(
        'assets/models/testdir/model.bin',
        filename: 'custom_name.bin',
      );
      final normalized = result.replaceAll('\\', '/');
      // Should use the provided filename
      expect(normalized, endsWith('/custom_name.bin'));
      // Should NOT contain the original subdirectory structure from asset path
      expect(normalized, isNot(contains('/testdir/model.bin')));
    });

    test('with empty filename falls back to asset path', () async {
      final result = await helper.loadAssetToCache(
        'assets/models/testdir/model.bin',
        filename: '',
      );
      final normalized = result.replaceAll('\\', '/');
      expect(normalized, contains('/models/models/testdir/model.bin'));
    });

    test('asset path without assets/ prefix still works', () async {
      // When path does NOT start with 'assets/', replaceFirst has no effect
      // But rootBundle won't find it either; this tests the path building logic
      // We'll just verify the path structure via the file-exists shortcut
      final dir = await helper.modelsDir;
      final preFile = File('$dir/models/testdir/model.bin');
      await preFile.parent.create(recursive: true);
      await preFile.writeAsBytes([1, 2, 3]);

      final result =
          await helper.loadAssetToCache('models/testdir/model.bin');
      final normalized = result.replaceAll('\\', '/');
      expect(normalized, contains('/models/models/testdir/model.bin'));
    });
  });

  // ---------------------------------------------------------------------------
  // loadAssetToCache
  // ---------------------------------------------------------------------------

  group('loadAssetToCache', () {
    test('returns cached path on cache hit (in-memory cache)', () async {
      final first =
          await helper.loadAssetToCache('assets/models/testdir/model.bin');
      final second =
          await helper.loadAssetToCache('assets/models/testdir/model.bin');
      expect(first, equals(second));
    });

    test('returns existing file path when file already exists on disk',
        () async {
      // Pre-create the target file
      final dir = await helper.modelsDir;
      final targetFile = File('$dir/models/testdir/model.bin');
      await targetFile.parent.create(recursive: true);
      await targetFile.writeAsBytes([99, 98, 97]);

      final result =
          await helper.loadAssetToCache('assets/models/testdir/model.bin');
      expect(result, equals(targetFile.path));

      // File content should be the pre-created content, not overwritten
      final content = await File(result).readAsBytes();
      expect(content, equals([99, 98, 97]));
    });

    test('copies asset bytes to cache on new file', () async {
      final result =
          await helper.loadAssetToCache('assets/models/testdir/model.bin');
      final file = File(result);
      expect(await file.exists(), isTrue);
      final bytes = await file.readAsBytes();
      expect(bytes, equals([10, 20, 30]));
    });

    test('creates parent directories as needed', () async {
      final result =
          await helper.loadAssetToCache('assets/models/testdir/model.bin');
      expect(Directory(result).parent.existsSync(), isTrue);
    });

    test('rethrows when asset does not exist in rootBundle', () async {
      expect(
        () => helper.loadAssetToCache('assets/models/nonexistent/file.bin'),
        throwsA(anything),
      );
    });

    test('caches the path after successful load', () async {
      await helper.loadAssetToCache('assets/models/testdir/tokenizer.json');
      // Second call should hit in-memory cache
      final second =
          await helper.loadAssetToCache('assets/models/testdir/tokenizer.json');
      expect(second, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // loadModelAssets
  // ---------------------------------------------------------------------------

  group('loadModelAssets', () {
    test('with modelFile returns modelPath', () async {
      final result = await helper.loadModelAssets(
        modelDir: 'testdir',
        modelFile: 'model.bin',
      );
      expect(result, contains('modelPath'));
      expect(result['modelPath'], isNotNull);
      expect(result, isNot(contains('tokenizerPath')));
    });

    test('with tokenizerFile returns tokenizerPath', () async {
      final result = await helper.loadModelAssets(
        modelDir: 'testdir',
        tokenizerFile: 'tokenizer.json',
      );
      expect(result, contains('tokenizerPath'));
      expect(result['tokenizerPath'], isNotNull);
      expect(result, isNot(contains('modelPath')));
    });

    test('with both returns both paths', () async {
      final result = await helper.loadModelAssets(
        modelDir: 'testdir',
        modelFile: 'model.bin',
        tokenizerFile: 'tokenizer.json',
      );
      expect(result, contains('modelPath'));
      expect(result, contains('tokenizerPath'));
      expect(result.length, equals(2));
    });

    test('with neither returns empty map', () async {
      final result = await helper.loadModelAssets(modelDir: 'testdir');
      expect(result, isEmpty);
    });

    test('gracefully handles missing model file', () async {
      final result = await helper.loadModelAssets(
        modelDir: 'testdir',
        modelFile: 'nonexistent.bin',
      );
      // Should not contain modelPath since the load failed
      expect(result, isNot(contains('modelPath')));
    });

    test('gracefully handles missing tokenizer file', () async {
      final result = await helper.loadModelAssets(
        modelDir: 'testdir',
        tokenizerFile: 'nonexistent.json',
      );
      expect(result, isNot(contains('tokenizerPath')));
    });

    test('one failure does not prevent the other from loading', () async {
      final result = await helper.loadModelAssets(
        modelDir: 'testdir',
        modelFile: 'nonexistent.bin',
        tokenizerFile: 'tokenizer.json',
      );
      expect(result, isNot(contains('modelPath')));
      expect(result, contains('tokenizerPath'));
    });
  });

  // ---------------------------------------------------------------------------
  // _isMissingAssetError via getAssetPath
  // ---------------------------------------------------------------------------

  group('_isMissingAssetError via getAssetPath', () {
    test('returns null for missing asset (Unable to load asset)', () async {
      // rootBundle.load throws FlutterError for non-existent assets.
      // getAssetPath should catch it via _isMissingAssetError and return null.
      final result =
          await helper.getAssetPath('assets/models/missing_one.bin');
      expect(result, isNull);
    });

    test('returns null for another missing asset path', () async {
      final result =
          await helper.getAssetPath('assets/models/missing_two.bin');
      expect(result, isNull);
    });

    test('rethrows non-missing-asset errors', () async {
      // Override path_provider to throw a StateError, which is NOT a
      // FlutterError containing "Unable to load asset". This causes
      // loadAssetToCache to rethrow, and _isMissingAssetError returns false,
      // so getAssetPath rethrows the error.
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (call) async {
        if (call.method == 'getApplicationCacheDirectory') {
          throw StateError('Cache directory unavailable');
        }
        return null;
      });

      try {
        expect(
          () => helper.getAssetPath('assets/models/testdir/model.bin'),
          throwsA(isA<PlatformException>()),
        );
      } finally {
        // Restore the normal path_provider mock
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationCacheDirectory') {
            return testCacheDir.path;
          }
          return null;
        });
      }
    });
  });

  // ---------------------------------------------------------------------------
  // getAssetPath
  // ---------------------------------------------------------------------------

  group('getAssetPath', () {
    test('returns path on success', () async {
      final result = await helper.getAssetPath('assets/models/testdir/model.bin');
      expect(result, isNotNull);
      expect(result, isNotEmpty);
    });

    test('returns null when asset is missing', () async {
      final result =
          await helper.getAssetPath('assets/models/definitely_missing.bin');
      expect(result, isNull);
    });

    test('returns cached path on subsequent calls', () async {
      final first = await helper.getAssetPath('assets/models/testdir/model.bin');
      final second = await helper.getAssetPath('assets/models/testdir/model.bin');
      expect(first, equals(second));
    });
  });

  // ---------------------------------------------------------------------------
  // getOptimizedAssetPath
  // ---------------------------------------------------------------------------

  group('getOptimizedAssetPath', () {
    test('falls back to getAssetPath on non-mobile platform', () async {
      // In test environment, Platform.isIOS and Platform.isAndroid are false
      final result =
          await helper.getOptimizedAssetPath('assets/models/testdir/model.bin');
      expect(result, isNotNull);
      // Should be the same as what getAssetPath returns
      final directResult =
          await helper.getAssetPath('assets/models/testdir/model.bin');
      expect(result, equals(directResult));
    });

    test('returns null for missing asset on non-mobile', () async {
      final result = await helper
          .getOptimizedAssetPath('assets/models/definitely_missing.bin');
      expect(result, isNull);
    });

    test('on non-mobile does not call runtime channel', () async {
      runtimeCalls.clear();
      await helper.getOptimizedAssetPath('assets/models/testdir/model.bin');
      // On non-mobile, the runtime channel should not be invoked
      expect(runtimeCalls, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // clearCache
  // ---------------------------------------------------------------------------

  group('clearCache', () {
    test('deletes models directory when it exists', () async {
      // Create a file in the models dir
      final dir = await helper.modelsDir;
      final testFile = File('$dir/test_file.txt');
      await testFile.writeAsString('test');

      expect(testFile.existsSync(), isTrue);

      await helper.clearCache();

      // After clear, loading again should re-create and copy
      // The directory may have been re-created by modelsDir getter,
      // but the file should be gone
      expect(File('${testCacheDir.path}/models/test_file.txt').existsSync(),
          isFalse);
    });

    test('does nothing when models directory does not exist', () async {
      // Delete models dir first if it exists
      final modelsDirPath = Directory('${testCacheDir.path}/models');
      if (modelsDirPath.existsSync()) {
        modelsDirPath.deleteSync(recursive: true);
      }

      // Should not throw
      await helper.clearCache();
    });

    test('clears in-memory path cache', () async {
      // Load something into cache
      await helper.loadAssetToCache('assets/models/testdir/model.bin');
      await helper.clearCache();
      // Next load should go through the full path, not return from memory cache
      final result =
          await helper.loadAssetToCache('assets/models/testdir/model.bin');
      expect(result, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // getCacheSize
  // ---------------------------------------------------------------------------

  group('getCacheSize', () {
    test('returns 0 when models directory does not exist', () async {
      final modelsDirPath = Directory('${testCacheDir.path}/models');
      if (modelsDirPath.existsSync()) {
        modelsDirPath.deleteSync(recursive: true);
      }
      final size = await helper.getCacheSize();
      expect(size, equals(0));
    });

    test('returns total file size when models directory has files', () async {
      // Load assets to create files in cache
      await helper.loadAssetToCache('assets/models/testdir/model.bin');
      await helper.loadAssetToCache('assets/models/testdir/tokenizer.json');

      final size = await helper.getCacheSize();
      // model.bin = [10,20,30] = 3 bytes, tokenizer.json = [40,50,60] = 3 bytes
      expect(size, equals(6));
    });

    test('returns 0 for empty models directory', () async {
      // Create the models dir but leave it empty
      final dir = await helper.modelsDir;
      expect(Directory(dir).existsSync(), isTrue);

      // Clear the files we might have created
      await helper.clearCache();
      // Recreate empty dir
      await Directory(dir).create(recursive: true);

      final size = await helper.getCacheSize();
      expect(size, equals(0));
    });
  });

  // ---------------------------------------------------------------------------
  // cacheDir and modelsDir getters
  // ---------------------------------------------------------------------------

  group('directory getters', () {
    test('cacheDir returns the application cache directory', () async {
      final dir = await helper.cacheDir;
      expect(dir, equals(testCacheDir.path));
    });

    test('modelsDir creates and returns models subdirectory', () async {
      final dir = await helper.modelsDir;
      expect(dir, equals('${testCacheDir.path}/models'));
      expect(Directory(dir).existsSync(), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Singleton behavior
  // ---------------------------------------------------------------------------

  group('singleton', () {
    test('returns the same instance', () {
      final a = AssetHelper();
      final b = AssetHelper();
      expect(identical(a, b), isTrue);
    });
  });
}
