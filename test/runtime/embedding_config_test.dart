import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/runtime/embedding_runtime.dart';

void main() {
  group('EmbeddingConfig', () {
    test('toJson with only required fields (modelPath)', () {
      const config = EmbeddingConfig(modelPath: '/path/to/model.onnx');
      expect(config.toJson(), {
        'modelPath': '/path/to/model.onnx',
        'tokenizerPath': null,
        'maxLength': 512,
      });
    });

    test('toJson with all fields set', () {
      const config = EmbeddingConfig(
        modelPath: '/path/to/model.onnx',
        tokenizerPath: '/path/to/tokenizer.json',
        maxLength: 256,
      );
      expect(config.toJson(), {
        'modelPath': '/path/to/model.onnx',
        'tokenizerPath': '/path/to/tokenizer.json',
        'maxLength': 256,
      });
    });

    test('toJson with custom maxLength only', () {
      const config = EmbeddingConfig(
        modelPath: '/path/to/model.onnx',
        maxLength: 1024,
      );
      expect(config.toJson(), {
        'modelPath': '/path/to/model.onnx',
        'tokenizerPath': null,
        'maxLength': 1024,
      });
    });

    test('null optional fields are included in toJson (not omitted)', () {
      const config = EmbeddingConfig(modelPath: '/path/to/model.onnx');
      final json = config.toJson();
      // EmbeddingConfig always includes all fields, even null
      expect(json.containsKey('tokenizerPath'), isTrue);
      expect(json['tokenizerPath'], isNull);
    });

    test('maxLength has correct default value', () {
      const config = EmbeddingConfig(modelPath: '/path/to/model.onnx');
      expect(config.maxLength, 512);
    });
  });
}
