import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/runtime/model_format.dart';

void main() {
  group('ModelFormat', () {
    test('modelFormat extension detects gguf', () {
      expect('model.gguf'.modelFormat, ModelFormat.gguf);
      expect('MODEL.GGUF'.modelFormat, ModelFormat.gguf);
    });

    test('modelFormat extension detects onnx', () {
      expect('model.onnx'.modelFormat, ModelFormat.onnx);
    });

    test('modelFormat extension detects safetensors', () {
      expect('model.safetensors'.modelFormat, ModelFormat.safetensors);
    });

    test('modelFormat extension detects bin', () {
      expect('model.bin'.modelFormat, ModelFormat.bin);
    });

    test('modelFormat extension returns unknown for other formats', () {
      expect('model.txt'.modelFormat, ModelFormat.unknown);
      expect('model.pt'.modelFormat, ModelFormat.unknown);
    });

    test('LocalModelInfo can be constructed', () {
      final info = LocalModelInfo(
        id: 'test-id',
        name: 'test.bin',
        path: '/path/to/test.bin',
        format: ModelFormat.bin,
        size: 1024,
      );
      expect(info.id, 'test-id');
      expect(info.name, 'test.bin');
      expect(info.size, 1024);
      expect(info.lastModified, isNull);
    });
  });
}
