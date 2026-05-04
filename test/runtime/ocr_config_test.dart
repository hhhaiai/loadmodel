import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/runtime/ocr_runtime.dart';

void main() {
  group('OCRParams', () {
    test('toJson with all fields null returns empty map', () {
      const params = OCRParams();
      expect(params.toJson(), isEmpty);
    });

    test('toJson with all optional fields set', () {
      const params = OCRParams(
        language: 'chi_sim',
        detectDirection: true,
        angleThreshold: 0.5,
      );
      expect(params.toJson(), {
        'language': 'chi_sim',
        'detect_direction': true,
        'angle_threshold': 0.5,
      });
    });

    test('toJson with some optional fields set', () {
      const params = OCRParams(language: 'eng');
      expect(params.toJson(), {
        'language': 'eng',
      });
    });

    test('null optional fields are omitted from toJson', () {
      const params = OCRParams(detectDirection: false);
      final json = params.toJson();
      expect(json.containsKey('language'), isFalse);
      expect(json.containsKey('angle_threshold'), isFalse);
    });
  });

  group('OCRConfig', () {
    test('toJson with default values (only required fields)', () {
      const config = OCRConfig(modelPath: '/path/to/model.onnx');
      expect(config.toJson(), {
        'modelPath': '/path/to/model.onnx',
        'language': 'eng+chi_sim',
        'config': null,
      });
    });

    test('toJson with all fields set', () {
      const config = OCRConfig(
        modelPath: '/path/to/model.onnx',
        language: 'eng',
        config: {'detection_threshold': 0.7},
      );
      expect(config.toJson(), {
        'modelPath': '/path/to/model.onnx',
        'language': 'eng',
        'config': {'detection_threshold': 0.7},
      });
    });

    test('null optional fields are included in toJson (not omitted)', () {
      const config = OCRConfig(modelPath: '/path/to/model.onnx');
      final json = config.toJson();
      // OCRConfig always includes all fields, even null
      expect(json.containsKey('config'), isTrue);
      expect(json['config'], isNull);
    });
  });
}
