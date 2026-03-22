import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/core/config_manager.dart';

void main() {
  group('QuantizationLevel', () {
    test('has all expected values', () {
      expect(QuantizationLevel.values, contains(QuantizationLevel.q2_K));
      expect(QuantizationLevel.values, contains(QuantizationLevel.q3_K_S));
      expect(QuantizationLevel.values, contains(QuantizationLevel.q3_K_M));
      expect(QuantizationLevel.values, contains(QuantizationLevel.q4_0));
      expect(QuantizationLevel.values, contains(QuantizationLevel.q4_K_S));
      expect(QuantizationLevel.values, contains(QuantizationLevel.q4_K_M));
      expect(QuantizationLevel.values, contains(QuantizationLevel.q5_0));
      expect(QuantizationLevel.values, contains(QuantizationLevel.q5_1));
      expect(QuantizationLevel.values, contains(QuantizationLevel.q8_0));
      expect(QuantizationLevel.values, contains(QuantizationLevel.f16));
      expect(QuantizationLevel.values, contains(QuantizationLevel.f32));
    });

    test('name returns correct string', () {
      expect(QuantizationLevel.q4_0.name, equals('q4_0'));
      expect(QuantizationLevel.q8_0.name, equals('q8_0'));
    });
  });

  group('QuantizationLevelExtension', () {
    test('displayName returns formatted string for q2_K', () {
      expect(QuantizationLevel.q2_K.displayName, contains('Q2_K'));
    });

    test('displayName returns formatted string for q4_0', () {
      expect(QuantizationLevel.q4_0.displayName, contains('Q4'));
    });

    test('displayName returns formatted string for f16', () {
      expect(QuantizationLevel.f16.displayName, contains('FP16'));
    });
  });

  group('QuantizationConfig', () {
    test('creates with default values', () {
      const config = QuantizationConfig();
      expect(config.level, QuantizationLevel.q4_K_M);
      expect(config.threads, 4);
      expect(config.enableGPU, isTrue);
      expect(config.gpuLayers, 32);
    });

    test('creates with custom values', () {
      const config = QuantizationConfig(
        level: QuantizationLevel.q8_0,
        threads: 8,
        enableGPU: false,
        gpuLayers: 0,
      );
      expect(config.level, QuantizationLevel.q8_0);
      expect(config.threads, 8);
      expect(config.enableGPU, isFalse);
      expect(config.gpuLayers, 0);
    });

    test('toJson produces correct output', () {
      const config = QuantizationConfig(
        level: QuantizationLevel.q4_0,
        threads: 6,
      );
      final json = config.toJson();
      expect(json['level'], 'q4_0');
      expect(json['threads'], 6);
    });

    test('fromJson parses complete data', () {
      final json = {
        'level': 'q8_0',
        'threads': 8,
        'enableGPU': true,
        'gpuLayers': 16,
      };
      final config = QuantizationConfig.fromJson(json);
      expect(config.level, QuantizationLevel.q8_0);
      expect(config.threads, 8);
      expect(config.enableGPU, isTrue);
      expect(config.gpuLayers, 16);
    });

    test('fromJson handles unknown level with default', () {
      final json = {'level': 'unknown_level'};
      final config = QuantizationConfig.fromJson(json);
      expect(config.level, QuantizationLevel.q4_K_M);
    });
  });

  group('ConfigManager', () {
    test('creates instance', () {
      final manager = ConfigManager();
      expect(manager, isNotNull);
    });
  });
}
