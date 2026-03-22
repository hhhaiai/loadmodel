import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/core/local_model_manager.dart';
import 'package:model_loader/runtime/model_format.dart';

void main() {
  group('LocalModelManager', () {
    test('supportedFormats contains expected formats', () {
      expect(LocalModelManager.supportedFormats, contains('.gguf'));
      expect(LocalModelManager.supportedFormats, contains('.onnx'));
      expect(LocalModelManager.supportedFormats, contains('.safetensors'));
      expect(LocalModelManager.supportedFormats, contains('.bin'));
    });

    test('creates instance', () {
      final manager = LocalModelManager();
      expect(manager, isA<LocalModelManager>());
    });

    test('scanModels returns empty list for non-existent directory', () async {
      final manager = LocalModelManager();
      final models = await manager.scanModels('/nonexistent/directory');
      expect(models, isEmpty);
    });

    test('scanModels returns empty list for empty directory', () async {
      final tempDir = Directory.systemTemp.createTempSync('empty_model_test_');
      try {
        final manager = LocalModelManager();
        final models = await manager.scanModels(tempDir.path);
        expect(models, isEmpty);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('scanModels finds GGUF files', () async {
      final tempDir = Directory.systemTemp.createTempSync('model_scan_test_');
      try {
        // Create a test file
        final testFile = File('${tempDir.path}/test.gguf');
        testFile.writeAsBytesSync([1, 2, 3]);

        final manager = LocalModelManager();
        final models = await manager.scanModels(tempDir.path);
        expect(models.length, 1);
        expect(models.first.name, 'test.gguf');
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('scanModels finds ONNX files', () async {
      final tempDir = Directory.systemTemp.createTempSync('model_scan_test_');
      try {
        final testFile = File('${tempDir.path}/model.onnx');
        testFile.writeAsBytesSync([1, 2, 3]);

        final manager = LocalModelManager();
        final models = await manager.scanModels(tempDir.path);
        expect(models.length, 1);
        expect(models.first.format, ModelFormat.onnx);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('scanModels ignores unsupported files', () async {
      final tempDir = Directory.systemTemp.createTempSync('model_scan_test_');
      try {
        final testFile = File('${tempDir.path}/test.txt');
        testFile.writeAsBytesSync([1, 2, 3]);

        final manager = LocalModelManager();
        final models = await manager.scanModels(tempDir.path);
        expect(models, isEmpty);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('scanModels scans recursively', () async {
      final tempDir = Directory.systemTemp.createTempSync('model_scan_test_');
      try {
        // Create a subdirectory with a model
        final subDir = Directory('${tempDir.path}/subdir');
        subDir.createSync();
        final testFile = File('${subDir.path}/nested.gguf');
        testFile.writeAsBytesSync([1, 2, 3]);

        final manager = LocalModelManager();
        final models = await manager.scanModels(tempDir.path);
        expect(models.length, 1);
        expect(models.first.name, 'nested.gguf');
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
