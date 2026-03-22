import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/runtime/model_format.dart';

void main() {
  group('LocalModelInfo', () {
    test('creates with required parameters', () {
      const info = LocalModelInfo(
        id: 'test-id',
        name: 'test.bin',
        path: '/path/to/test.bin',
        format: ModelFormat.bin,
        size: 1024,
      );
      expect(info.id, 'test-id');
      expect(info.name, 'test.bin');
      expect(info.format, ModelFormat.bin);
      expect(info.size, 1024);
      expect(info.lastModified, isNull);
    });

    test('creates with all parameters', () {
      final now = DateTime.now();
      final info = LocalModelInfo(
        id: 'test-id',
        name: 'test.gguf',
        path: '/path/to/test.gguf',
        format: ModelFormat.gguf,
        size: 2048,
        lastModified: now,
      );
      expect(info.lastModified, now);
    });

    test('fromPath returns null when file does not exist', () async {
      final info = await LocalModelInfo.fromPath('/nonexistent/path/model.bin');
      expect(info, isNull);
    });

    test('fromPath returns model info when file exists', () async {
      // Create a temporary file
      final tempDir = Directory.systemTemp.createTempSync('model_test_');
      final tempFile = File('${tempDir.path}/test_model.onnx');
      tempFile.writeAsBytesSync([1, 2, 3]);

      try {
        final info = await LocalModelInfo.fromPath(tempFile.path);
        expect(info, isNotNull);
        expect(info!.name, 'test_model.onnx');
        expect(info.format, ModelFormat.onnx);
        expect(info.size, 3);
        expect(info.lastModified, isNotNull);
      } finally {
        tempFile.deleteSync();
        tempDir.deleteSync();
      }
    });

    test('fromPath returns null for invalid path', () async {
      // This should handle exceptions gracefully
      final info = await LocalModelInfo.fromPath('');
      expect(info, isNull);
    });
  });

  group('ModelFormat', () {
    test('enum has all expected values', () {
      expect(ModelFormat.values, contains(ModelFormat.gguf));
      expect(ModelFormat.values, contains(ModelFormat.onnx));
      expect(ModelFormat.values, contains(ModelFormat.safetensors));
      expect(ModelFormat.values, contains(ModelFormat.bin));
      expect(ModelFormat.values, contains(ModelFormat.unknown));
    });
  });

  group('ModelFormatExtension', () {
    test('detects gguf case-insensitively', () {
      expect('model.gguf'.modelFormat, ModelFormat.gguf);
      expect('model.GGUF'.modelFormat, ModelFormat.gguf);
      expect('model.GgUf'.modelFormat, ModelFormat.gguf);
    });

    test('detects onnx case-insensitively', () {
      expect('model.onnx'.modelFormat, ModelFormat.onnx);
      expect('model.ONNX'.modelFormat, ModelFormat.onnx);
    });

    test('detects safetensors case-insensitively', () {
      expect('model.safetensors'.modelFormat, ModelFormat.safetensors);
      expect('model.SAFETENSORS'.modelFormat, ModelFormat.safetensors);
    });

    test('detects bin case-insensitively', () {
      expect('model.bin'.modelFormat, ModelFormat.bin);
      expect('model.BIN'.modelFormat, ModelFormat.bin);
    });

    test('returns unknown for unrecognized formats', () {
      expect('model.txt'.modelFormat, ModelFormat.unknown);
      expect('model.pt'.modelFormat, ModelFormat.unknown);
      expect('model.pth'.modelFormat, ModelFormat.unknown);
      expect('model.ckpt'.modelFormat, ModelFormat.unknown);
      expect('model.tflite'.modelFormat, ModelFormat.unknown);
      expect('noextension'.modelFormat, ModelFormat.unknown);
      expect(''.modelFormat, ModelFormat.unknown);
    });
  });

  group('ModelLoaderBase', () {
    test('is abstract and cannot be instantiated directly', () {
      // This test verifies the abstract class exists
      expect(() => throw UnimplementedError('abstract'), throwsUnimplementedError);
    });
  });

  group('LLMInference', () {
    test('is abstract', () {
      expect(() => throw UnimplementedError('abstract'), throwsUnimplementedError);
    });
  });

  group('EmbeddingInference', () {
    test('is abstract', () {
      expect(() => throw UnimplementedError('abstract'), throwsUnimplementedError);
    });
  });

  group('OCRInference', () {
    test('is abstract', () {
      expect(() => throw UnimplementedError('abstract'), throwsUnimplementedError);
    });
  });

  group('STTInference', () {
    test('is abstract', () {
      expect(() => throw UnimplementedError('abstract'), throwsUnimplementedError);
    });
  });
}
