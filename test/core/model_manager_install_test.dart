import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/core/model_manager.dart';
import 'package:model_loader/models/download_task.dart';
import 'package:model_loader/models/model_info.dart';
import 'package:model_loader/models/model_type.dart';

void main() {
  group('ModelManager install state machine', () {
    late Directory tempDir;
    late HttpServer server;
    late String downloadUrl;
    late List<int> payload;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('model_loader_install_test_');
      payload = utf8.encode('fixture-model-bytes-for-sha256');

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path == '/model.bin') {
          request.response.statusCode = 200;
          request.response.headers.contentLength = payload.length;
          request.response.add(payload);
        } else {
          request.response.statusCode = 404;
        }
        await request.response.close();
      });

      downloadUrl = 'http://${server.address.host}:${server.port}/model.bin';
    });

    tearDown(() async {
      await server.close(force: true);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('installs into version directory and emits ready', () async {
      final manager = ModelManager(cacheDir: tempDir.path, enableRemoteModels: false);
      await manager.init();

      final expectedSha = sha256.convert(payload).toString();
      final model = ModelInfo(
        id: 'embed-test',
        name: 'Embedding Test',
        type: ModelType.embedding,
        format: 'onnx',
        version: '1.2.3',
        size: payload.length,
        downloadUrl: downloadUrl,
        sha256: expectedSha,
      );

      final phases = <InstallPhase>[];
      final sub = manager.installProgressStream.listen((event) {
        if (event.modelId == model.id && event.version == model.version) {
          phases.add(event.phase);
        }
      });

      addTearDown(() async {
        await sub.cancel();
        manager.dispose();
      });

      await manager.installModel(model).drain<void>();

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(phases.contains(InstallPhase.downloading), isTrue);
      expect(phases.contains(InstallPhase.verifying), isTrue);
      expect(phases.contains(InstallPhase.ready), isTrue);

      final versionDir = Directory('${tempDir.path}/${model.id}/${model.version}');
      final readyFile = File('${versionDir.path}/.ready');
      final artifactFile = File('${versionDir.path}/${model.id}.${model.format}');

      expect(await versionDir.exists(), isTrue);
      expect(await readyFile.exists(), isTrue);
      expect(await artifactFile.exists(), isTrue);
      expect(await manager.isModelDownloaded(model.id, version: model.version), isTrue);
      expect(await manager.getModelPath(model.id, version: model.version), artifactFile.path);
    });

    test('emits failed on sha mismatch and does not create ready marker', () async {
      final manager = ModelManager(cacheDir: tempDir.path, enableRemoteModels: false);
      await manager.init();

      final model = ModelInfo(
        id: 'embed-test-bad-sha',
        name: 'Embedding Bad Sha',
        type: ModelType.embedding,
        format: 'onnx',
        version: '0.0.1',
        size: payload.length,
        downloadUrl: downloadUrl,
        sha256: 'deadbeef',
      );

      final events = <InstallProgress>[];
      final sub = manager.installProgressStream.listen((event) {
        if (event.modelId == model.id && event.version == model.version) {
          events.add(event);
        }
      });

      addTearDown(() async {
        await sub.cancel();
        manager.dispose();
      });

      await expectLater(
        manager.installModel(model).drain<void>(),
        throwsA(isA<Object>()),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final failedEvents = events.where((e) => e.phase == InstallPhase.failed).toList();
      expect(failedEvents.isNotEmpty, isTrue);
      expect(
        failedEvents.any((e) => e.error?['code'] == 'MODEL_VERIFY_FAILED'),
        isTrue,
      );

      final readyFile = File('${tempDir.path}/${model.id}/${model.version}/.ready');
      expect(await readyFile.exists(), isFalse);
      expect(await manager.isModelDownloaded(model.id, version: model.version), isFalse);
    });

    test('fails when actual download exceeds expected size', () async {
      final manager = ModelManager(cacheDir: tempDir.path, enableRemoteModels: false);
      await manager.init();

      final model = ModelInfo(
        id: 'embed-test-size-overflow',
        name: 'Embedding Size Overflow',
        type: ModelType.embedding,
        format: 'onnx',
        version: '0.0.2',
        size: payload.length - 1,
        downloadUrl: downloadUrl,
      );

      final events = <InstallProgress>[];
      final sub = manager.installProgressStream.listen((event) {
        if (event.modelId == model.id && event.version == model.version) {
          events.add(event);
        }
      });

      addTearDown(() async {
        await sub.cancel();
        manager.dispose();
      });

      await expectLater(
        manager.installModel(model).drain<void>(),
        throwsA(isA<Object>()),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final failedEvents = events.where((e) => e.phase == InstallPhase.failed).toList();
      expect(failedEvents.isNotEmpty, isTrue);
      expect(
        failedEvents.any((e) => e.error?['code'] == 'DOWNLOAD_SIZE_EXCEEDED'),
        isTrue,
      );

      final readyFile = File('${tempDir.path}/${model.id}/${model.version}/.ready');
      expect(await readyFile.exists(), isFalse);
    });
  });
}
