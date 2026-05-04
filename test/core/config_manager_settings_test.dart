import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/core/config_manager.dart';

void main() {
  group('ConfigManager settings methods', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'model_loader_settings_test_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('setCustomModelPath sets and persists the value', () async {
      final manager = ConfigManager(configDir: tempDir.path);
      await manager.init();

      await manager.setCustomModelPath('/custom/model/path');

      expect(manager.customModelPath, '/custom/model/path');

      // Verify persistence by creating a new instance
      final manager2 = ConfigManager(configDir: tempDir.path);
      await manager2.init();
      expect(manager2.customModelPath, '/custom/model/path');
    });

    test('setModelCacheDir sets and persists the value', () async {
      final manager = ConfigManager(configDir: tempDir.path);
      await manager.init();

      await manager.setModelCacheDir('/custom/cache/dir');

      expect(manager.modelCacheDir, '/custom/cache/dir');

      // Verify persistence
      final manager2 = ConfigManager(configDir: tempDir.path);
      await manager2.init();
      expect(manager2.modelCacheDir, '/custom/cache/dir');
    });

    test('modelCacheDir getter returns default when not set', () {
      final manager = ConfigManager(configDir: tempDir.path);
      // Before init, no config file exists, so it should return default
      // We can't easily test the PlatformUtils default, but we can verify
      // the field is not explicitly set after init with no file
      expect(manager.modelCacheDir, isNotEmpty);
    });

    test('setRemoteModelListUrl sets and persists the value', () async {
      final manager = ConfigManager(configDir: tempDir.path);
      await manager.init();

      await manager.setRemoteModelListUrl('https://models.example.com/list');

      expect(manager.remoteModelListUrl, 'https://models.example.com/list');

      // Verify persistence
      final manager2 = ConfigManager(configDir: tempDir.path);
      await manager2.init();
      expect(manager2.remoteModelListUrl, 'https://models.example.com/list');
    });

    test('setQuantizationConfig sets and persists the value', () async {
      final manager = ConfigManager(configDir: tempDir.path);
      await manager.init();

      const config = QuantizationConfig(
        level: QuantizationLevel.q8_0,
        threads: 6,
        enableGPU: false,
        gpuLayers: 16,
      );
      await manager.setQuantizationConfig(config);

      expect(manager.quantizationConfig, isNotNull);
      expect(manager.quantizationConfig!.level, QuantizationLevel.q8_0);
      expect(manager.quantizationConfig!.threads, 6);
      expect(manager.quantizationConfig!.enableGPU, false);
      expect(manager.quantizationConfig!.gpuLayers, 16);

      // Verify persistence
      final manager2 = ConfigManager(configDir: tempDir.path);
      await manager2.init();
      expect(manager2.quantizationConfig!.level, QuantizationLevel.q8_0);
      expect(manager2.quantizationConfig!.threads, 6);
      expect(manager2.quantizationConfig!.enableGPU, false);
      expect(manager2.quantizationConfig!.gpuLayers, 16);
    });

    test('setQuantizationConfig updates existing config', () async {
      final manager = ConfigManager(configDir: tempDir.path);
      await manager.init();

      const config1 = QuantizationConfig(
        level: QuantizationLevel.q4_0,
        threads: 4,
        enableGPU: true,
        gpuLayers: 32,
      );
      await manager.setQuantizationConfig(config1);

      const config2 = QuantizationConfig(
        level: QuantizationLevel.q2_K,
        threads: 8,
        enableGPU: false,
        gpuLayers: 0,
      );
      await manager.setQuantizationConfig(config2);

      expect(manager.quantizationConfig!.level, QuantizationLevel.q2_K);
      expect(manager.quantizationConfig!.threads, 8);
      expect(manager.quantizationConfig!.enableGPU, false);
      expect(manager.quantizationConfig!.gpuLayers, 0);
    });

    test('setUISettings sets and persists the value', () async {
      final manager = ConfigManager(configDir: tempDir.path);
      await manager.init();

      await manager.setUISettings({
        'theme': 'dark',
        'language': 'en',
        'notifications': true,
      });

      final settings = manager.uiSettings;
      expect(settings['theme'], 'dark');
      expect(settings['language'], 'en');
      expect(settings['notifications'], true);

      // Verify persistence
      final manager2 = ConfigManager(configDir: tempDir.path);
      await manager2.init();
      expect(manager2.uiSettings['theme'], 'dark');
      expect(manager2.uiSettings['language'], 'en');
      expect(manager2.uiSettings['notifications'], true);
    });

    test('all setters work together and persist', () async {
      final manager = ConfigManager(configDir: tempDir.path);
      await manager.init();

      await manager.setCustomModelPath('/all/setters/path');
      await manager.setModelCacheDir('/all/setters/cache');
      await manager.setRemoteModelListUrl('https://example.com/models');
      await manager.setQuantizationConfig(const QuantizationConfig(
        level: QuantizationLevel.f16,
        threads: 2,
      ));
      await manager.setUISettings({'key': 'value'});

      // Verify all values are set
      expect(manager.customModelPath, '/all/setters/path');
      expect(manager.modelCacheDir, '/all/setters/cache');
      expect(manager.remoteModelListUrl, 'https://example.com/models');
      expect(manager.quantizationConfig!.level, QuantizationLevel.f16);
      expect(manager.uiSettings['key'], 'value');

      // Reload and verify all persisted
      final manager2 = ConfigManager(configDir: tempDir.path);
      await manager2.init();
      expect(manager2.customModelPath, '/all/setters/path');
      expect(manager2.modelCacheDir, '/all/setters/cache');
      expect(manager2.remoteModelListUrl, 'https://example.com/models');
      expect(manager2.quantizationConfig!.level, QuantizationLevel.f16);
      expect(manager2.uiSettings['key'], 'value');
    });

    test('customModelPath returns null when not set', () async {
      final manager = ConfigManager(configDir: tempDir.path);
      await manager.init();
      expect(manager.customModelPath, isNull);
    });

    test('remoteModelListUrl returns null when not set', () async {
      final manager = ConfigManager(configDir: tempDir.path);
      await manager.init();
      expect(manager.remoteModelListUrl, isNull);
    });

    test('quantizationConfig returns null when not set', () async {
      final manager = ConfigManager(configDir: tempDir.path);
      await manager.init();
      expect(manager.quantizationConfig, isNull);
    });

    test('uiSettings returns empty map when not set', () async {
      final manager = ConfigManager(configDir: tempDir.path);
      await manager.init();
      expect(manager.uiSettings, isEmpty);
    });
  });
}
