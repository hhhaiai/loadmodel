import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/runtime/stt_runtime.dart';

void main() {
  group('STTParams', () {
    test('toJson with all fields null returns empty map', () {
      const params = STTParams();
      expect(params.toJson(), isEmpty);
    });

    test('toJson with all optional fields set', () {
      const params = STTParams(
        language: 'en',
        translate: true,
        timestamps: false,
        multilingual: true,
        chunkSize: 4096,
      );
      expect(params.toJson(), {
        'language': 'en',
        'translate': true,
        'timestamps': false,
        'multilingual': true,
        'chunk_size': 4096,
      });
    });

    test('toJson with some optional fields set', () {
      const params = STTParams(language: 'zh', timestamps: true);
      expect(params.toJson(), {
        'language': 'zh',
        'timestamps': true,
      });
    });

    test('null optional fields are omitted from toJson', () {
      const params = STTParams(language: 'en');
      final json = params.toJson();
      expect(json.containsKey('translate'), isFalse);
      expect(json.containsKey('timestamps'), isFalse);
      expect(json.containsKey('multilingual'), isFalse);
      expect(json.containsKey('chunk_size'), isFalse);
    });
  });

  group('STTConfig', () {
    test('toJson with default values (only required fields)', () {
      const config = STTConfig(modelPath: '/path/to/model.onnx');
      expect(config.toJson(), {
        'modelPath': '/path/to/model.onnx',
        'language': 'auto',
        'sampleRate': 16000,
        'config': null,
      });
    });

    test('toJson with all fields set', () {
      const config = STTConfig(
        modelPath: '/path/to/model.onnx',
        language: 'en',
        sampleRate: 48000,
        config: {'beam_size': 5},
      );
      expect(config.toJson(), {
        'modelPath': '/path/to/model.onnx',
        'language': 'en',
        'sampleRate': 48000,
        'config': {'beam_size': 5},
      });
    });

    test('null optional fields are included in toJson (not omitted)', () {
      const config = STTConfig(modelPath: '/path/to/model.onnx');
      final json = config.toJson();
      // STTConfig always includes all fields, even null
      expect(json.containsKey('config'), isTrue);
      expect(json['config'], isNull);
    });
  });
}
