import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/runtime/embedding_runtime.dart';
import 'package:model_loader/runtime/onnx_runtime_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(kModelRuntimeChannel);
  MethodCall? lastLoadEmbeddingCall;

  group('ONNX Embedding runtime load', () {
    Future<Object?> defaultEmbeddingHandler(MethodCall call) async {
      switch (call.method) {
        case 'loadEmbeddingModel':
          lastLoadEmbeddingCall = call;
          return true;
        case 'unloadEmbeddingModel':
          return null;
        case 'getEmbedding':
          return {
            'embedding': [0.1, 0.2, 0.3],
            'dimension': 3,
          };
        default:
          throw PlatformException(
            code: 'UNIMPLEMENTED',
            message: 'Unknown method: ${call.method}',
          );
      }
    }

    Future<Object?> embeddingLoadFailHandler(MethodCall call) async {
      if (call.method == 'loadEmbeddingModel') {
        return false;
      }
      return defaultEmbeddingHandler(call);
    }

    setUp(() async {
      lastLoadEmbeddingCall = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, defaultEmbeddingHandler);
      await ONNXRuntimes.embedding.unloadModel();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('loads embedding model and toggles isLoaded', () async {
      final runtime = ONNXRuntimes.embedding;

      expect(runtime.isLoaded, isFalse);

      await runtime.loadModel(const EmbeddingConfig(
        modelPath: '/tmp/mock_model.onnx',
        tokenizerPath: '/tmp/mock_tokenizer.json',
        maxLength: 384,
      ));

      expect(runtime.isLoaded, isTrue);
      expect(lastLoadEmbeddingCall, isNotNull);
      expect(lastLoadEmbeddingCall!.arguments, isA<Map>());
      final embeddingLoadArgs = Map<String, dynamic>.from(
        lastLoadEmbeddingCall!.arguments as Map<dynamic, dynamic>,
      );
      expect(embeddingLoadArgs['modelPath'], equals('/tmp/mock_model.onnx'));
      expect(embeddingLoadArgs['tokenizerPath'], equals('/tmp/mock_tokenizer.json'));
      expect(embeddingLoadArgs['maxLength'], equals(384));

      final result = await runtime.getEmbedding('hello');
      expect(result.dimension, equals(3));
      expect(result.embedding.length, equals(3));

      await runtime.unloadModel();
      expect(runtime.isLoaded, isFalse);
    });

    test('throws when native returns false on embedding load', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, embeddingLoadFailHandler);

      final runtime = ONNXRuntimes.embedding;
      await expectLater(
        runtime.loadModel(const EmbeddingConfig(modelPath: '/tmp/mock_model.onnx')),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'LOAD_ERROR'),
        ),
      );
      expect(runtime.isLoaded, isFalse);
    });

    test('rejects non-onnx model path', () async {
      final runtime = ONNXRuntimes.embedding;
      await expectLater(
        runtime.loadModel(const EmbeddingConfig(modelPath: '/tmp/mock_model.gguf')),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'INVALID_ARGS'),
        ),
      );
      expect(runtime.isLoaded, isFalse);
    });

    test('rejects remote model path', () async {
      final runtime = ONNXRuntimes.embedding;
      await expectLater(
        runtime.loadModel(const EmbeddingConfig(modelPath: 'https://example.com/model.onnx')),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'INVALID_ARGS'),
        ),
      );
      expect(runtime.isLoaded, isFalse);
    });

    test('rejects http remote model path', () async {
      final runtime = ONNXRuntimes.embedding;
      await expectLater(
        runtime.loadModel(const EmbeddingConfig(modelPath: 'http://example.com/model.onnx')),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'INVALID_ARGS'),
        ),
      );
      expect(runtime.isLoaded, isFalse);
    });

    test('rejects empty model path', () async {
      final runtime = ONNXRuntimes.embedding;
      await expectLater(
        runtime.loadModel(const EmbeddingConfig(modelPath: '')),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'INVALID_ARGS'),
        ),
      );
      expect(runtime.isLoaded, isFalse);
    });

    test('rejects whitespace-only model path', () async {
      final runtime = ONNXRuntimes.embedding;
      await expectLater(
        runtime.loadModel(const EmbeddingConfig(modelPath: '   ')),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'INVALID_ARGS'),
        ),
      );
      expect(runtime.isLoaded, isFalse);
    });

    test('accepts uppercase ONNX extension', () async {
      final runtime = ONNXRuntimes.embedding;
      await runtime.loadModel(const EmbeddingConfig(modelPath: '/tmp/EMBED_MODEL.ONNX'));
      expect(runtime.isLoaded, isTrue);
      await runtime.unloadModel();
      expect(runtime.isLoaded, isFalse);
    });
  });
}
