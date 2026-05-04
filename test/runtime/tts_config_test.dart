import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/runtime/tts_runtime.dart';

void main() {
  group('TTSParams', () {
    test('toJson with all fields null returns empty map', () {
      const params = TTSParams();
      expect(params.toJson(), isEmpty);
    });

    test('toJson with all optional fields set', () {
      const params = TTSParams(
        speed: 1.5,
        pitch: 0.8,
        volume: 0.9,
        voice: 'zh-CN female',
        format: 'wav',
      );
      expect(params.toJson(), {
        'speed': 1.5,
        'pitch': 0.8,
        'volume': 0.9,
        'voice': 'zh-CN female',
        'format': 'wav',
      });
    });

    test('toJson with some optional fields set', () {
      const params = TTSParams(speed: 2.0, voice: 'en-US');
      expect(params.toJson(), {
        'speed': 2.0,
        'voice': 'en-US',
      });
    });

    test('null optional fields are omitted from toJson', () {
      const params = TTSParams(speed: 1.0);
      final json = params.toJson();
      expect(json.containsKey('pitch'), isFalse);
      expect(json.containsKey('volume'), isFalse);
      expect(json.containsKey('voice'), isFalse);
      expect(json.containsKey('format'), isFalse);
    });
  });

  group('TTSConfig', () {
    test('toJson with default values (only required fields)', () {
      const config = TTSConfig(modelPath: '/path/to/model.onnx');
      expect(config.toJson(), {
        'modelPath': '/path/to/model.onnx',
        'language': null,
        'sampleRate': 22050,
        'config': null,
      });
    });

    test('toJson with all fields set', () {
      const config = TTSConfig(
        modelPath: '/path/to/model.onnx',
        language: 'zh-CN',
        sampleRate: 44100,
        config: {'key': 'value'},
      );
      expect(config.toJson(), {
        'modelPath': '/path/to/model.onnx',
        'language': 'zh-CN',
        'sampleRate': 44100,
        'config': {'key': 'value'},
      });
    });

    test('null optional fields are included in toJson (not omitted)', () {
      const config = TTSConfig(modelPath: '/path/to/model.onnx');
      final json = config.toJson();
      // TTSConfig always includes all fields, even null
      expect(json.containsKey('language'), isTrue);
      expect(json.containsKey('config'), isTrue);
      expect(json['language'], isNull);
      expect(json['config'], isNull);
    });
  });
}
