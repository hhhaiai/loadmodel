import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/runtime/runtime_factory.dart';
import 'package:model_loader/models/model_type.dart';

void main() {
  group('RuntimeFactory', () {
    group('PlatformInfo', () {
      test('creates with all parameters', () {
        const platform = PlatformInfo(
          name: 'test',
          isMobile: true,
          isDesktop: false,
          isIOS: true,
          isAndroid: false,
          isMacOS: false,
          isWindows: false,
          isLinux: false,
        );

        expect(platform.name, equals('test'));
        expect(platform.isMobile, isTrue);
        expect(platform.isDesktop, isFalse);
        expect(platform.isIOS, isTrue);
      });

      test('current creates PlatformInfo', () {
        final platform = PlatformInfo.current();
        expect(platform.name, isNotEmpty);
      });
    });

    group('RuntimeConfig', () {
      test('creates with required parameters', () {
        const config = RuntimeConfig(
          runtime: 'test',
          priority: 1,
          description: 'Test runtime',
        );

        expect(config.runtime, equals('test'));
        expect(config.priority, equals(1));
      });
    });

    group('getBestConfig', () {
      test('returns llama.cpp for LLM on desktop', () {
        const platform = PlatformInfo(
          name: 'macOS',
          isMobile: false,
          isDesktop: true,
          isIOS: false,
          isAndroid: false,
          isMacOS: true,
          isWindows: false,
          isLinux: false,
        );

        final config = RuntimeFactory.getBestConfig(platform, ModelType.llm);
        expect(config.runtime, equals('llama.cpp'));
      });

      test('returns llama.cpp for LLM on mobile', () {
        const platform = PlatformInfo(
          name: 'android',
          isMobile: true,
          isDesktop: false,
          isIOS: false,
          isAndroid: true,
          isMacOS: false,
          isWindows: false,
          isLinux: false,
        );

        final config = RuntimeFactory.getBestConfig(platform, ModelType.llm);
        expect(config.runtime, equals('llama.cpp'));
      });

      test('returns onnx for LLM on unknown platform', () {
        const platform = PlatformInfo(
          name: 'unknown',
          isMobile: false,
          isDesktop: false,
          isIOS: false,
          isAndroid: false,
          isMacOS: false,
          isWindows: false,
          isLinux: false,
        );

        final config = RuntimeFactory.getBestConfig(platform, ModelType.llm);
        expect(config.runtime, equals('onnx'));
      });

      test('returns onnx for embedding', () {
        const platform = PlatformInfo(
          name: 'macOS',
          isMobile: false,
          isDesktop: true,
          isIOS: false,
          isAndroid: false,
          isMacOS: true,
          isWindows: false,
          isLinux: false,
        );

        final config = RuntimeFactory.getBestConfig(platform, ModelType.embedding);
        expect(config.runtime, equals('onnx'));
      });

      test('returns onnx for STT', () {
        const platform = PlatformInfo(
          name: 'android',
          isMobile: true,
          isDesktop: false,
          isIOS: false,
          isAndroid: true,
          isMacOS: false,
          isWindows: false,
          isLinux: false,
        );

        final config = RuntimeFactory.getBestConfig(platform, ModelType.stt);
        expect(config.runtime, equals('onnx'));
      });

      test('returns onnx for TTS', () {
        const platform = PlatformInfo(
          name: 'iOS',
          isMobile: true,
          isDesktop: false,
          isIOS: true,
          isAndroid: false,
          isMacOS: false,
          isWindows: false,
          isLinux: false,
        );

        final config = RuntimeFactory.getBestConfig(platform, ModelType.tts);
        expect(config.runtime, equals('onnx'));
      });

      test('returns onnx for OCR', () {
        const platform = PlatformInfo(
          name: 'windows',
          isMobile: false,
          isDesktop: true,
          isIOS: false,
          isAndroid: false,
          isMacOS: false,
          isWindows: true,
          isLinux: false,
        );

        final config = RuntimeFactory.getBestConfig(platform, ModelType.ocr);
        expect(config.runtime, equals('onnx'));
      });

      test('returns onnx for classification', () {
        const platform = PlatformInfo(
          name: 'linux',
          isMobile: false,
          isDesktop: true,
          isIOS: false,
          isAndroid: false,
          isMacOS: false,
          isWindows: false,
          isLinux: true,
        );

        final config = RuntimeFactory.getBestConfig(platform, ModelType.classification);
        expect(config.runtime, equals('onnx'));
      });

      test('returns onnx for custom model type', () {
        const platform = PlatformInfo(
          name: 'macOS',
          isMobile: false,
          isDesktop: true,
          isIOS: false,
          isAndroid: false,
          isMacOS: true,
          isWindows: false,
          isLinux: false,
        );

        final config = RuntimeFactory.getBestConfig(platform, ModelType.custom);
        expect(config.runtime, equals('onnx'));
      });
    });
  });
}
