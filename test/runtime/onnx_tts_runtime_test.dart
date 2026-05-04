import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/runtime/onnx_runtime_flutter.dart';
import 'package:model_loader/runtime/tts_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(kModelRuntimeChannel);
  MethodCall? lastTTSCall;

  group('ONNX TTS runtime', () {
    Future<Object?> defaultTTSHandler(MethodCall call) async {
      lastTTSCall = call;
      switch (call.method) {
        case 'loadTTSModel':
          return true;
        case 'unloadTTSModel':
          return null;
        case 'synthesizeTTS':
          // Return the outputPath as the result
          final args = Map<String, dynamic>.from(call.arguments as Map);
          return args['outputPath'];
        default:
          throw PlatformException(
            code: 'UNIMPLEMENTED',
            message: 'Unknown method: ${call.method}',
          );
      }
    }

    Future<Object?> ttsLoadFailHandler(MethodCall call) async {
      if (call.method == 'loadTTSModel') {
        return false;
      }
      return defaultTTSHandler(call);
    }

    Future<Object?> ttsSynthesizeNullHandler(MethodCall call) async {
      if (call.method == 'synthesizeTTS') {
        return null;
      }
      return defaultTTSHandler(call);
    }

    setUp(() async {
      lastTTSCall = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, defaultTTSHandler);
      await ONNXRuntimes.tts.unloadModel();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('loadModel success toggles isLoaded to true', () async {
      final runtime = ONNXRuntimes.tts;

      expect(runtime.isLoaded, isFalse);

      await runtime.loadModel(const TTSConfig(
        modelPath: '/tmp/mock_tts_model.onnx',
        language: 'en-US',
      ));

      expect(runtime.isLoaded, isTrue);
      expect(lastTTSCall, isNotNull);
      expect(lastTTSCall!.method, equals('loadTTSModel'));
      final args = Map<String, dynamic>.from(lastTTSCall!.arguments as Map);
      expect(args['language'], equals('en-US'));
    });

    test('loadModel failure throws PlatformException with LOAD_ERROR', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, ttsLoadFailHandler);

      final runtime = ONNXRuntimes.tts;
      await expectLater(
        runtime.loadModel(const TTSConfig(
          modelPath: '/tmp/mock_tts_model.onnx',
        )),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'LOAD_ERROR'),
        ),
      );
      expect(runtime.isLoaded, isFalse);
    });

    test('unloadModel toggles isLoaded to false', () async {
      final runtime = ONNXRuntimes.tts;

      await runtime.loadModel(const TTSConfig(
        modelPath: '/tmp/mock_tts_model.onnx',
      ));
      expect(runtime.isLoaded, isTrue);

      await runtime.unloadModel();
      expect(runtime.isLoaded, isFalse);
      expect(lastTTSCall!.method, equals('unloadTTSModel'));
    });

    test('synthesize with valid outputPath returns path', () async {
      final runtime = ONNXRuntimes.tts;
      await runtime.loadModel(const TTSConfig(
        modelPath: '/tmp/mock_tts_model.onnx',
      ));

      final outputPath = '/tmp/test_output.wav';
      final result = await runtime.synthesize('Hello world', outputPath: outputPath);

      expect(result, equals(outputPath));
      expect(lastTTSCall!.method, equals('synthesizeTTS'));
      final args = Map<String, dynamic>.from(lastTTSCall!.arguments as Map);
      expect(args['text'], equals('Hello world'));
      expect(args['outputPath'], equals(outputPath));
    });

    test('synthesize with null outputPath throws PlatformException INVALID_ARGS', () async {
      final runtime = ONNXRuntimes.tts;
      await runtime.loadModel(const TTSConfig(
        modelPath: '/tmp/mock_tts_model.onnx',
      ));

      await expectLater(
        runtime.synthesize('Hello world', outputPath: null),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'INVALID_ARGS'),
        ),
      );
    });

    test('synthesize with empty outputPath throws PlatformException INVALID_ARGS', () async {
      final runtime = ONNXRuntimes.tts;
      await runtime.loadModel(const TTSConfig(
        modelPath: '/tmp/mock_tts_model.onnx',
      ));

      await expectLater(
        runtime.synthesize('Hello world', outputPath: ''),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'INVALID_ARGS'),
        ),
      );
    });

    test('synthesize when channel returns null throws PlatformException SYNTHESIS_ERROR', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, ttsSynthesizeNullHandler);

      final runtime = ONNXRuntimes.tts;
      await runtime.loadModel(const TTSConfig(
        modelPath: '/tmp/mock_tts_model.onnx',
      ));

      await expectLater(
        runtime.synthesize('Hello world', outputPath: '/tmp/test_output.wav'),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'SYNTHESIS_ERROR'),
        ),
      );
    });

    test('synthesize passes TTSParams to channel', () async {
      final runtime = ONNXRuntimes.tts;
      await runtime.loadModel(const TTSConfig(
        modelPath: '/tmp/mock_tts_model.onnx',
      ));

      await runtime.synthesize(
        'Hello world',
        outputPath: '/tmp/test_output.wav',
        params: const TTSParams(
          speed: 1.2,
          pitch: 0.8,
          volume: 0.9,
          voice: 'en-US',
        ),
      );

      final args = Map<String, dynamic>.from(lastTTSCall!.arguments as Map);
      expect(args['speed'], equals(1.2));
      expect(args['pitch'], equals(0.8));
      expect(args['volume'], equals(0.9));
      expect(args['voice'], equals('en-US'));
    });

    test('synthesizeBytes creates temp file and returns bytes', () async {
      final runtime = ONNXRuntimes.tts;
      await runtime.loadModel(const TTSConfig(
        modelPath: '/tmp/mock_tts_model.onnx',
      ));

      // Override synthesizeTTS to create a real temp file with content
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'synthesizeTTS') {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final outputPath = args['outputPath'] as String;
          // Create a minimal valid WAV file header
          final file = File(outputPath);
          final wavHeader = Uint8List(44);
          // RIFF header
          wavHeader.setRange(0, 4, [0x52, 0x49, 0x46, 0x46]); // RIFF
          // File size - 8 (will be filled)
          wavHeader[4] = 0x24;
          wavHeader[5] = 0x00;
          wavHeader[6] = 0x00;
          wavHeader[7] = 0x00;
          // WAVE
          wavHeader.setRange(8, 12, [0x57, 0x41, 0x56, 0x45]); // WAVE
          // fmt
          wavHeader.setRange(12, 16, [0x66, 0x6D, 0x74, 0x20]); // fmt
          // Chunk size
          wavHeader[16] = 0x10;
          wavHeader[17] = 0x00;
          wavHeader[18] = 0x00;
          wavHeader[19] = 0x00;
          // Audio format (1 = PCM)
          wavHeader[20] = 0x01;
          wavHeader[21] = 0x00;
          // Num channels (1 = mono)
          wavHeader[22] = 0x01;
          wavHeader[23] = 0x00;
          // Sample rate
          wavHeader[24] = 0x44;
          wavHeader[25] = 0xAC;
          wavHeader[26] = 0x00;
          wavHeader[27] = 0x00;
          // Byte rate
          wavHeader[28] = 0x88;
          wavHeader[29] = 0x58;
          wavHeader[30] = 0x01;
          wavHeader[31] = 0x00;
          // Block align
          wavHeader[32] = 0x02;
          wavHeader[33] = 0x00;
          // Bits per sample
          wavHeader[34] = 0x10;
          wavHeader[35] = 0x00;
          // data
          wavHeader.setRange(36, 40, [0x64, 0x61, 0x74, 0x61]); // data
          // Data size
          wavHeader[40] = 0x00;
          wavHeader[41] = 0x00;
          wavHeader[42] = 0x00;
          wavHeader[43] = 0x00;
          await file.writeAsBytes(wavHeader);
          return outputPath;
        }
        return defaultTTSHandler(call);
      });

      final bytes = await runtime.synthesizeBytes('Hello');

      expect(bytes, isNotEmpty);
      expect(bytes.length, equals(44)); // Just the header we wrote
    });

    test('synthesizeBytes cleans up temp file after success', () async {
      final runtime = ONNXRuntimes.tts;
      await runtime.loadModel(const TTSConfig(
        modelPath: '/tmp/mock_tts_model.onnx',
      ));

      String? capturedTempPath;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'synthesizeTTS') {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final outputPath = args['outputPath'] as String;
          capturedTempPath = outputPath;
          final file = File(outputPath);
          await file.writeAsBytes(Uint8List(44)); // Minimal WAV header
          return outputPath;
        }
        return defaultTTSHandler(call);
      });

      await runtime.synthesizeBytes('Hello');

      // Verify temp file was cleaned up
      expect(capturedTempPath, isNotNull);
      final tempFile = File(capturedTempPath!);
      expect(await tempFile.exists(), isFalse);
    });

    test('getAvailableVoices returns list of voice identifiers', () async {
      final runtime = ONNXRuntimes.tts;

      final voices = await runtime.getAvailableVoices();

      expect(voices, isA<List<String>>());
      expect(voices, contains('en-US'));
      expect(voices, contains('zh-CN'));
    });
  });
}
