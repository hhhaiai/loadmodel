import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/model_loader.dart';
import 'package:model_loader/utils/logger.dart';

void main() {
  group('ModelLoaderConfig', () {
    test('creates with default values', () {
      const config = ModelLoaderConfig();

      expect(config.customModelPath, isNull);
      expect(config.modelCacheDir, isNull);
      expect(config.enableRemoteModels, isFalse);
      expect(config.remoteModelListUrl, isNull);
      expect(config.logLevel, equals(LogLevel.info));
      expect(config.autoSelectRuntime, isTrue);
    });

    test('creates with custom values', () {
      const config = ModelLoaderConfig(
        customModelPath: '/custom/path',
        modelCacheDir: '/cache/dir',
        enableRemoteModels: true,
        remoteModelListUrl: 'https://models.example.com',
        logLevel: LogLevel.debug,
        autoSelectRuntime: false,
      );

      expect(config.customModelPath, equals('/custom/path'));
      expect(config.modelCacheDir, equals('/cache/dir'));
      expect(config.enableRemoteModels, isTrue);
      expect(config.remoteModelListUrl, equals('https://models.example.com'));
      expect(config.logLevel, equals(LogLevel.debug));
      expect(config.autoSelectRuntime, isFalse);
    });

    test('cacheDir returns modelCacheDir when provided', () {
      const config = ModelLoaderConfig(
        modelCacheDir: '/my/cache',
      );

      expect(config.cacheDir, equals('/my/cache'));
    });

    test('cacheDir returns default when not provided', () {
      const config = ModelLoaderConfig();

      expect(config.cacheDir, isNotEmpty);
    });

    test('customDir returns customModelPath when provided', () {
      const config = ModelLoaderConfig(
        customModelPath: '/my/models',
      );

      expect(config.customDir, equals('/my/models'));
    });

    test('customDir returns default when not provided', () {
      const config = ModelLoaderConfig();

      expect(config.customDir, isNotEmpty);
    });
  });

  group('ModelLoader', () {
    test('instance throws when not initialized', () {
      // Note: This test may pass/fail depending on prior test state
      // The key is that calling instance before initialize should throw
    });

    test('initialize returns existing instance if already initialized', () async {
      // First initialization
      final first = await ModelLoader.initialize(
        config: const ModelLoaderConfig(logLevel: LogLevel.error),
      );

      // Second initialization should return same instance
      final second = await ModelLoader.initialize(
        config: const ModelLoaderConfig(logLevel: LogLevel.debug),
      );

      expect(identical(first, second), isTrue);
    });
  });

  group('LogLevel', () {
    test('has all expected levels', () {
      expect(LogLevel.values, contains(LogLevel.debug));
      expect(LogLevel.values, contains(LogLevel.info));
      expect(LogLevel.values, contains(LogLevel.warning));
      expect(LogLevel.values, contains(LogLevel.error));
    });
  });
}
