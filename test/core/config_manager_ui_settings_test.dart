import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/core/config_manager.dart';

void main() {
  group('ConfigManager UI settings', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'model_loader_config_test_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('setUISettings persists and reloads settings', () async {
      final manager = ConfigManager(configDir: tempDir.path);
      await manager.init();

      await manager.setUISettings({
        'selectedLLMModel': 'tinyllama',
        'selectedEmbeddingModel': 'bge-small',
        'temperature': 0.7,
        'maxTokens': 1024,
        'contextLength': 2048,
        'systemPrompt': '请直接回答',
      });

      final file = File('${tempDir.path}/config.json');
      expect(await file.exists(), isTrue);

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      expect(json['uiSettings'], isA<Map<String, dynamic>>());
      expect(
        (json['uiSettings'] as Map<String, dynamic>)['selectedLLMModel'],
        equals('tinyllama'),
      );

      final manager2 = ConfigManager(configDir: tempDir.path);
      await manager2.init();

      final loaded = manager2.uiSettings;
      expect(loaded['selectedLLMModel'], equals('tinyllama'));
      expect(loaded['selectedEmbeddingModel'], equals('bge-small'));
      expect((loaded['temperature'] as num).toDouble(), equals(0.7));
      expect((loaded['maxTokens'] as num).toInt(), equals(1024));
      expect((loaded['contextLength'] as num).toInt(), equals(2048));
      expect(loaded['systemPrompt'], equals('请直接回答'));
    });

    test('uiSettings getter returns copy', () async {
      final manager = ConfigManager(configDir: tempDir.path);
      await manager.init();
      await manager.setUISettings({'selectedLLMModel': 'tinyllama'});

      final snapshot = manager.uiSettings;
      snapshot['selectedLLMModel'] = 'changed';

      expect(manager.uiSettings['selectedLLMModel'], equals('tinyllama'));
    });

    test('uiSettings getter deep-copies nested structures', () async {
      final manager = ConfigManager(configDir: tempDir.path);
      await manager.init();
      await manager.setUISettings({
        'nested': {
          'list': [1, 2, 3],
        },
      });

      final snapshot = manager.uiSettings;
      final nested = snapshot['nested'] as Map<String, dynamic>;
      final list = nested['list'] as List<dynamic>;
      list.add(4);

      final readback = manager.uiSettings;
      final readbackNested = readback['nested'] as Map<String, dynamic>;
      final readbackList = readbackNested['list'] as List<dynamic>;
      expect(readbackList, equals([1, 2, 3]));
    });
  });
}
