import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/runtime/ocr_runtime.dart';
import 'package:model_loader/runtime/onnx_runtime_flutter.dart';
import 'package:model_loader/runtime/stt_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(kModelRuntimeChannel);
  MethodCall? lastLoadSTTCall;
  MethodCall? lastLoadOCRCall;
  MethodCall? lastRecognizeSTTCall;
  MethodCall? lastRecognizeOCRCall;

  group('ONNX STT/OCR runtimes', () {
    Future<Object?> defaultSttOcrHandler(MethodCall call) async {
      switch (call.method) {
        case 'loadSTTModel':
          lastLoadSTTCall = call;
          return true;
        case 'unloadSTTModel':
          return null;
        case 'loadOCRModel':
          lastLoadOCRCall = call;
          return true;
        case 'unloadOCRModel':
          return null;
        case 'recognizeSTT':
          lastRecognizeSTTCall = call;
          return {'text': 'hello world', 'confidence': 0.87, 'language': 'en'};
        case 'recognizeOCR':
          lastRecognizeOCRCall = call;
          return {'text': 'sample ocr', 'confidence': 0.66};
        default:
          throw PlatformException(
            code: 'UNIMPLEMENTED',
            message: 'Unknown method: ${call.method}',
          );
      }
    }

    Future<Object?> sttLoadFailHandler(MethodCall call) async {
      if (call.method == 'loadSTTModel') {
        return false;
      }
      return defaultSttOcrHandler(call);
    }

    Future<Object?> ocrLoadFailHandler(MethodCall call) async {
      if (call.method == 'loadOCRModel') {
        return false;
      }
      return defaultSttOcrHandler(call);
    }

    Future<Object?> placeholderSttHandler(MethodCall call) async {
      if (call.method == 'recognizeSTT') {
        lastRecognizeSTTCall = call;
        return {
          'text': 'Speech recognition result (placeholder)',
          'confidence': 0.0,
          'language': 'zh',
        };
      }
      return defaultSttOcrHandler(call);
    }

    Future<Object?> placeholderOcrHandler(MethodCall call) async {
      if (call.method == 'recognizeOCR') {
        lastRecognizeOCRCall = call;
        return {
          'text': 'OCR result (model-specific preprocessing required)',
          'confidence': 0.0,
        };
      }
      return defaultSttOcrHandler(call);
    }

    setUp(() async {
      lastLoadSTTCall = null;
      lastLoadOCRCall = null;
      lastRecognizeSTTCall = null;
      lastRecognizeOCRCall = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, defaultSttOcrHandler);
      await ONNXRuntimes.stt.unloadModel();
      await ONNXRuntimes.ocr.unloadModel();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('stt load/recognize/unload works through channel', () async {
      final stt = ONNXRuntimes.stt;
      expect(stt.isLoaded, isFalse);

      await stt.loadModel(
        const STTConfig(modelPath: '/tmp/stt.onnx', language: 'zh'),
      );
      expect(stt.isLoaded, isTrue);
      expect(lastLoadSTTCall, isNotNull);
      expect(lastLoadSTTCall!.arguments, isA<Map>());
      final sttLoadArgs = Map<String, dynamic>.from(
        lastLoadSTTCall!.arguments as Map<dynamic, dynamic>,
      );
      expect(sttLoadArgs['modelPath'], equals('/tmp/stt.onnx'));
      expect(sttLoadArgs['language'], equals('zh'));

      final sttInput = Uint8List.fromList(List<int>.filled(3200, 0));
      final result = await stt.recognizeBytes(sttInput);
      expect(result.text, equals('hello world'));
      expect(result.language, equals('en'));
      expect(result.confidence, closeTo(0.87, 1e-9));

      expect(lastRecognizeSTTCall, isNotNull);
      expect(lastRecognizeSTTCall!.method, equals('recognizeSTT'));
      final sttRecognizeArgs = Map<String, dynamic>.from(
        lastRecognizeSTTCall!.arguments as Map<dynamic, dynamic>,
      );
      expect(sttRecognizeArgs['language'], equals('auto'));
      expect(sttRecognizeArgs['audioData'], isA<Uint8List>());
      expect(
        (sttRecognizeArgs['audioData'] as Uint8List).length,
        equals(sttInput.length),
      );
      expect((sttRecognizeArgs['audioData'] as Uint8List), equals(sttInput));

      await stt.unloadModel();
      expect(stt.isLoaded, isFalse);
    });

    test(
      'stt recognizeBytes sends explicit language when params are provided',
      () async {
        final stt = ONNXRuntimes.stt;
        await stt.loadModel(const STTConfig(modelPath: '/tmp/stt.onnx'));

        await stt.recognizeBytes(
          Uint8List.fromList(const [1, 2, 3, 4]),
          params: const STTParams(language: 'zh'),
        );

        expect(lastRecognizeSTTCall, isNotNull);
        expect(lastRecognizeSTTCall!.method, equals('recognizeSTT'));
        final sttRecognizeArgs = Map<String, dynamic>.from(
          lastRecognizeSTTCall!.arguments as Map<dynamic, dynamic>,
        );
        expect(sttRecognizeArgs['language'], equals('zh'));
        expect(sttRecognizeArgs['audioData'], isA<Uint8List>());
        expect(
          sttRecognizeArgs['audioData'],
          equals(Uint8List.fromList(const [1, 2, 3, 4])),
        );
      },
    );

    test('stt recognizeBytes rejects placeholder native payloads', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, placeholderSttHandler);

      final stt = ONNXRuntimes.stt;
      await stt.loadModel(const STTConfig(modelPath: '/tmp/stt.onnx'));

      await expectLater(
        stt.recognizeBytes(Uint8List.fromList(const [1, 2, 3, 4])),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'RUNTIME_NOT_AVAILABLE',
          ),
        ),
      );
    });

    test('stt load throws when native returns false', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, sttLoadFailHandler);

      final stt = ONNXRuntimes.stt;
      await expectLater(
        stt.loadModel(const STTConfig(modelPath: '/tmp/stt.onnx')),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'LOAD_ERROR'),
        ),
      );
      expect(stt.isLoaded, isFalse);
    });

    test('stt load rejects non-onnx model path', () async {
      final stt = ONNXRuntimes.stt;
      await expectLater(
        stt.loadModel(const STTConfig(modelPath: '/tmp/stt.gguf')),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'INVALID_ARGS',
          ),
        ),
      );
      expect(stt.isLoaded, isFalse);
    });

    test('stt load rejects remote model path', () async {
      final stt = ONNXRuntimes.stt;
      await expectLater(
        stt.loadModel(
          const STTConfig(modelPath: 'https://example.com/stt.onnx'),
        ),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'INVALID_ARGS',
          ),
        ),
      );
      expect(stt.isLoaded, isFalse);
    });

    test('stt load rejects http remote model path', () async {
      final stt = ONNXRuntimes.stt;
      await expectLater(
        stt.loadModel(
          const STTConfig(modelPath: 'http://example.com/stt.onnx'),
        ),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'INVALID_ARGS',
          ),
        ),
      );
      expect(stt.isLoaded, isFalse);
    });

    test('stt load rejects empty model path', () async {
      final stt = ONNXRuntimes.stt;
      await expectLater(
        stt.loadModel(const STTConfig(modelPath: '')),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'INVALID_ARGS',
          ),
        ),
      );
      expect(stt.isLoaded, isFalse);
    });

    test('stt load accepts uppercase ONNX extension', () async {
      final stt = ONNXRuntimes.stt;
      await stt.loadModel(const STTConfig(modelPath: '/tmp/STT_MODEL.ONNX'));
      expect(stt.isLoaded, isTrue);
      await stt.unloadModel();
      expect(stt.isLoaded, isFalse);
    });

    test('ocr load/recognize/unload works through channel', () async {
      final ocr = ONNXRuntimes.ocr;
      expect(ocr.isLoaded, isFalse);

      await ocr.loadModel(
        const OCRConfig(modelPath: '/tmp/ocr.onnx', language: 'eng+chi_sim'),
      );
      expect(ocr.isLoaded, isTrue);
      expect(lastLoadOCRCall, isNotNull);
      expect(lastLoadOCRCall!.arguments, isA<Map>());
      final ocrLoadArgs = Map<String, dynamic>.from(
        lastLoadOCRCall!.arguments as Map<dynamic, dynamic>,
      );
      expect(ocrLoadArgs['modelPath'], equals('/tmp/ocr.onnx'));
      expect(ocrLoadArgs['language'], equals('eng+chi_sim'));

      final ocrInput = Uint8List.fromList(const [137, 80, 78, 71]);
      final result = await ocr.recognizeBytes(ocrInput);
      expect(result.text, equals('sample ocr'));
      expect(result.averageConfidence, closeTo(0.66, 1e-9));

      expect(lastRecognizeOCRCall, isNotNull);
      expect(lastRecognizeOCRCall!.method, equals('recognizeOCR'));
      final ocrRecognizeArgs = Map<String, dynamic>.from(
        lastRecognizeOCRCall!.arguments as Map<dynamic, dynamic>,
      );
      expect(ocrRecognizeArgs['language'], equals('eng'));
      expect(ocrRecognizeArgs['imageData'], isA<Uint8List>());
      expect(
        (ocrRecognizeArgs['imageData'] as Uint8List).length,
        equals(ocrInput.length),
      );
      expect((ocrRecognizeArgs['imageData'] as Uint8List), equals(ocrInput));

      await ocr.unloadModel();
      expect(ocr.isLoaded, isFalse);
    });

    test(
      'ocr recognizeBytes sends explicit language when params are provided',
      () async {
        final ocr = ONNXRuntimes.ocr;
        await ocr.loadModel(const OCRConfig(modelPath: '/tmp/ocr.onnx'));

        await ocr.recognizeBytes(
          Uint8List.fromList(const [1, 2, 3, 4]),
          params: const OCRParams(language: 'chi_sim'),
        );

        expect(lastRecognizeOCRCall, isNotNull);
        expect(lastRecognizeOCRCall!.method, equals('recognizeOCR'));
        final ocrRecognizeArgs = Map<String, dynamic>.from(
          lastRecognizeOCRCall!.arguments as Map<dynamic, dynamic>,
        );
        expect(ocrRecognizeArgs['language'], equals('chi_sim'));
        expect(ocrRecognizeArgs['imageData'], isA<Uint8List>());
        expect(
          ocrRecognizeArgs['imageData'],
          equals(Uint8List.fromList(const [1, 2, 3, 4])),
        );
      },
    );

    test('ocr recognizeBytes rejects placeholder native payloads', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, placeholderOcrHandler);

      final ocr = ONNXRuntimes.ocr;
      await ocr.loadModel(const OCRConfig(modelPath: '/tmp/ocr.onnx'));

      await expectLater(
        ocr.recognizeBytes(Uint8List.fromList(const [1, 2, 3, 4])),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'RUNTIME_NOT_AVAILABLE',
          ),
        ),
      );
    });

    test('ocr load throws when native returns false', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, ocrLoadFailHandler);

      final ocr = ONNXRuntimes.ocr;
      await expectLater(
        ocr.loadModel(const OCRConfig(modelPath: '/tmp/ocr.onnx')),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'LOAD_ERROR'),
        ),
      );
      expect(ocr.isLoaded, isFalse);
    });

    test('ocr load rejects non-onnx model path', () async {
      final ocr = ONNXRuntimes.ocr;
      await expectLater(
        ocr.loadModel(const OCRConfig(modelPath: '/tmp/ocr.gguf')),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'INVALID_ARGS',
          ),
        ),
      );
      expect(ocr.isLoaded, isFalse);
    });

    test('ocr load rejects remote model path', () async {
      final ocr = ONNXRuntimes.ocr;
      await expectLater(
        ocr.loadModel(
          const OCRConfig(modelPath: 'https://example.com/ocr.onnx'),
        ),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'INVALID_ARGS',
          ),
        ),
      );
      expect(ocr.isLoaded, isFalse);
    });

    test('ocr load rejects http remote model path', () async {
      final ocr = ONNXRuntimes.ocr;
      await expectLater(
        ocr.loadModel(
          const OCRConfig(modelPath: 'http://example.com/ocr.onnx'),
        ),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'INVALID_ARGS',
          ),
        ),
      );
      expect(ocr.isLoaded, isFalse);
    });

    test('ocr load rejects empty model path', () async {
      final ocr = ONNXRuntimes.ocr;
      await expectLater(
        ocr.loadModel(const OCRConfig(modelPath: '')),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'INVALID_ARGS',
          ),
        ),
      );
      expect(ocr.isLoaded, isFalse);
    });

    test('ocr load accepts uppercase ONNX extension', () async {
      final ocr = ONNXRuntimes.ocr;
      await ocr.loadModel(const OCRConfig(modelPath: '/tmp/OCR_MODEL.ONNX'));
      expect(ocr.isLoaded, isTrue);
      await ocr.unloadModel();
      expect(ocr.isLoaded, isFalse);
    });
  });
}
