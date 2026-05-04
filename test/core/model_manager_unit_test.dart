import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/core/model_manager.dart';
import 'package:model_loader/models/model_type.dart';

void main() {
  group('DownloadLock', () {
    test('creates with required parameters', () {
      final lock = DownloadLock(modelId: 'model-1', version: '1.0.0');
      expect(lock.modelId, equals('model-1'));
      expect(lock.version, equals('1.0.0'));
      expect(lock.completer.isCompleted, isFalse);
    });

    test('createdAt is set to now', () {
      final before = DateTime.now();
      final lock = DownloadLock(modelId: 'model-1', version: '1.0.0');
      final after = DateTime.now();
      expect(lock.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(lock.createdAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });

  group('ModelManager', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('model_manager_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('creates with required parameters', () {
      final manager = ModelManager(cacheDir: tempDir.path);
      expect(manager, isNotNull);
    });

    test('creates with all optional parameters', () {
      final manager = ModelManager(
        cacheDir: tempDir.path,
        remoteModelListUrl: 'https://example.com/models.json',
        enableRemoteModels: true,
        downloadConnectTimeout: const Duration(seconds: 30),
        downloadReadTimeout: const Duration(minutes: 10),
        fallbackMaxDownloadBytes: 1024 * 1024,
      );
      expect(manager, isNotNull);
    });

    test('init creates cache directory', () async {
      final manager = ModelManager(cacheDir: tempDir.path);
      await manager.init();
      expect(await Directory(tempDir.path).exists(), isTrue);
      manager.dispose();
    });

    test('init handles existing directory', () async {
      final manager = ModelManager(cacheDir: tempDir.path);
      await manager.init();
      await manager.init(); // Should not throw
      manager.dispose();
    });

    test('dispose closes stream controller', () async {
      final manager = ModelManager(cacheDir: tempDir.path);
      await manager.init();
      manager.dispose();
      // After dispose, listening to stream should complete
      expect(manager.installProgressStream.isEmpty, completion(isTrue));
    });

    test('getLocalModels returns empty list initially', () async {
      final manager = ModelManager(cacheDir: tempDir.path);
      await manager.init();
      final models = await manager.getLocalModels();
      expect(models, isEmpty);
      manager.dispose();
    });

    test('remoteModels returns empty list initially', () async {
      final manager = ModelManager(cacheDir: tempDir.path);
      await manager.init();
      expect(manager.remoteModels, isEmpty);
      manager.dispose();
    });

    test('fetchRemoteModels returns empty when disabled', () async {
      final manager = ModelManager(
        cacheDir: tempDir.path,
        enableRemoteModels: false,
      );
      await manager.init();
      final models = await manager.fetchRemoteModels();
      expect(models, isEmpty);
      manager.dispose();
    });

    test('fetchRemoteModels returns empty when no URL', () async {
      final manager = ModelManager(
        cacheDir: tempDir.path,
        enableRemoteModels: true,
      );
      await manager.init();
      final models = await manager.fetchRemoteModels();
      expect(models, isEmpty);
      manager.dispose();
    });

    test('isModelDownloaded returns false for non-existent model', () async {
      final manager = ModelManager(cacheDir: tempDir.path);
      await manager.init();
      final result = await manager.isModelDownloaded('non-existent');
      expect(result, isFalse);
      manager.dispose();
    });

    test('isModelDownloaded returns false for non-existent version', () async {
      final manager = ModelManager(cacheDir: tempDir.path);
      await manager.init();
      final result = await manager.isModelDownloaded('model-1', version: '1.0.0');
      expect(result, isFalse);
      manager.dispose();
    });

    test('getModelPath returns null for non-existent model', () async {
      final manager = ModelManager(cacheDir: tempDir.path);
      await manager.init();
      final result = await manager.getModelPath('non-existent');
      expect(result, isNull);
      manager.dispose();
    });

    test('getModelPath returns null for non-existent version', () async {
      final manager = ModelManager(cacheDir: tempDir.path);
      await manager.init();
      final result = await manager.getModelPath('model-1', version: '1.0.0');
      expect(result, isNull);
      manager.dispose();
    });

    test('verifyModel returns false for non-existent model', () async {
      final manager = ModelManager(cacheDir: tempDir.path);
      await manager.init();
      final result = await manager.verifyModel('non-existent');
      expect(result, isFalse);
      manager.dispose();
    });

    test('deleteModel throws for non-existent model', () async {
      final manager = ModelManager(cacheDir: tempDir.path);
      await manager.init();
      expect(
        () => manager.deleteModel('non-existent'),
        throwsA(isA<Exception>()),
      );
      manager.dispose();
    });

    test('addCustomModel throws for non-existent file', () async {
      final manager = ModelManager(cacheDir: tempDir.path);
      await manager.init();
      expect(
        () => manager.addCustomModel(
          path: '/non/existent/file.gguf',
          type: ModelType.llm,
        ),
        throwsA(isA<FileSystemException>()),
      );
      manager.dispose();
    });

    test('addCustomModel adds model to local list', () async {
      final manager = ModelManager(cacheDir: tempDir.path);
      await manager.init();

      // Create a test file
      final testFile = File('${tempDir.path}/test.gguf');
      await testFile.writeAsString('test content');

      await manager.addCustomModel(
        path: testFile.path,
        type: ModelType.llm,
        name: 'Test Model',
      );

      final models = await manager.getLocalModels();
      expect(models.length, equals(1));
      expect(models.first.info.name, equals('Test Model'));
      expect(models.first.info.type, equals(ModelType.llm));
      manager.dispose();
    });

    test('installModel stream is broadcast', () async {
      final manager = ModelManager(cacheDir: tempDir.path, enableRemoteModels: false);
      await manager.init();

      // Stream should be broadcast (multiple listeners allowed)
      final sub1 = manager.installProgressStream.listen((_) {});
      final sub2 = manager.installProgressStream.listen((_) {});

      await sub1.cancel();
      await sub2.cancel();
      manager.dispose();
    });
  });

  group('ModelManager load/save local models', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('model_manager_save_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists local models across init', () async {
      // Create a test file
      final testFile = File('${tempDir.path}/test.gguf');
      await testFile.writeAsString('test content');

      // First manager adds a model
      final manager1 = ModelManager(cacheDir: tempDir.path);
      await manager1.init();
      await manager1.addCustomModel(
        path: testFile.path,
        type: ModelType.llm,
        name: 'Persisted Model',
      );
      manager1.dispose();

      // Second manager should load persisted models
      final manager2 = ModelManager(cacheDir: tempDir.path);
      await manager2.init();
      final models = await manager2.getLocalModels();
      expect(models.length, equals(1));
      expect(models.first.info.name, equals('Persisted Model'));
      manager2.dispose();
    });

    test('handles corrupted models.json', () async {
      // Write invalid JSON
      final modelsFile = File('${tempDir.path}/models.json');
      await modelsFile.writeAsString('invalid json');

      final manager = ModelManager(cacheDir: tempDir.path);
      await manager.init();
      final models = await manager.getLocalModels();
      expect(models, isEmpty);
      manager.dispose();
    });

    test('handles models.json with wrong format', () async {
      // Write JSON with wrong structure
      final modelsFile = File('${tempDir.path}/models.json');
      await modelsFile.writeAsString(jsonEncode({'wrong': 'format'}));

      final manager = ModelManager(cacheDir: tempDir.path);
      await manager.init();
      final models = await manager.getLocalModels();
      expect(models, isEmpty);
      manager.dispose();
    });

    test('handles models.json with non-list models', () async {
      // Write JSON with models as string instead of list
      final modelsFile = File('${tempDir.path}/models.json');
      await modelsFile.writeAsString(jsonEncode({'models': 'not a list'}));

      final manager = ModelManager(cacheDir: tempDir.path);
      await manager.init();
      final models = await manager.getLocalModels();
      expect(models, isEmpty);
      manager.dispose();
    });
  });
}
