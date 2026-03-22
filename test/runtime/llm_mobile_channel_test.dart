import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/runtime/llm_runtime.dart';
import 'package:model_loader/runtime/llm_runtime_mobile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.modelloader/model_runtime');

  group('LLMRuntimeMobile MethodChannel path', () {
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);

            switch (call.method) {
              case 'loadLLMModel':
                return true;
              case 'chatLLM':
                return 'hello-from-native';
              case 'chatLLMStream':
                return 'stream-from-native';
              case 'unloadLLMModel':
                return true;
              default:
                throw PlatformException(
                  code: 'UNIMPLEMENTED',
                  message: call.method,
                );
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('loads and chats through platform channel', () async {
      final runtime = LLMRuntimeMobile();

      await runtime.loadModel(const LLMConfig(modelPath: '/tmp/test.gguf'));
      expect(runtime.isLoaded, isTrue);

      final response = await runtime.chat([ChatMessage.user('hi')]);
      expect(response, equals('hello-from-native'));

      await runtime.unloadModel();
      expect(runtime.isLoaded, isFalse);

      expect(
        calls.map((c) => c.method),
        containsAll(['loadLLMModel', 'chatLLM', 'unloadLLMModel']),
      );
    });

    test('loadModel fails when native returns false', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'loadLLMModel') {
              return false;
            }
            return null;
          });

      final runtime = LLMRuntimeMobile();
      await expectLater(
        runtime.loadModel(const LLMConfig(modelPath: '/tmp/test.gguf')),
        throwsA(isA<PlatformException>()),
      );
      expect(runtime.isLoaded, isFalse);
    });

    test('chatStream uses chatLLMStream method', () async {
      final runtime = LLMRuntimeMobile();
      await runtime.loadModel(const LLMConfig(modelPath: '/tmp/test.gguf'));

      final chunks = await runtime.chatStream([
        ChatMessage.user('hello'),
      ]).toList();
      expect(chunks, equals(['stream-from-native']));
      expect(calls.any((c) => c.method == 'chatLLMStream'), isTrue);
    });

    test(
      'chatStream falls back to chatLLM when stream returns empty',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              switch (call.method) {
                case 'loadLLMModel':
                  return true;
                case 'chatLLMStream':
                  return '';
                case 'chatLLM':
                  return 'fallback-from-chat';
                default:
                  return true;
              }
            });

        final runtime = LLMRuntimeMobile();
        await runtime.loadModel(const LLMConfig(modelPath: '/tmp/test.gguf'));

        final chunks = await runtime.chatStream([
          ChatMessage.user('hello'),
        ]).toList();
        expect(chunks, equals(['fallback-from-chat']));
        expect(calls.any((c) => c.method == 'chatLLMStream'), isTrue);
        expect(calls.any((c) => c.method == 'chatLLM'), isTrue);
      },
    );

    test(
      'chatStream throws INFERENCE_FAILED when stream and fallback are empty',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              switch (call.method) {
                case 'loadLLMModel':
                  return true;
                case 'chatLLMStream':
                  return '';
                case 'chatLLM':
                  return '';
                default:
                  return true;
              }
            });

        final runtime = LLMRuntimeMobile();
        await runtime.loadModel(const LLMConfig(modelPath: '/tmp/test.gguf'));

        await expectLater(
          runtime.chatStream([ChatMessage.user('hello')]).toList(),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'INFERENCE_FAILED',
            ),
          ),
        );
      },
    );

    test(
      'sanitizes outbound generation params and sends structured messages',
      () async {
        final runtime = LLMRuntimeMobile();
        await runtime.loadModel(const LLMConfig(modelPath: '/tmp/test.gguf'));

        await runtime.chat(
          [ChatMessage.user('hello')],
          config: const GenerationConfig(
            temperature: 9.9,
            topP: -1.0,
            maxTokens: 999999,
          ),
        );

        final chatCall = calls.lastWhere((c) => c.method == 'chatLLM');
        final args = Map<String, dynamic>.from(
          chatCall.arguments as Map<dynamic, dynamic>,
        );
        expect(args['prompt'], isNull);
        expect(args['messages'], isA<List<dynamic>>());
        final messages = List<Map<dynamic, dynamic>>.from(
          args['messages'] as List<dynamic>,
        );
        expect(messages, hasLength(1));
        expect(messages.single['role'], equals('user'));
        expect(messages.single['content'], equals('hello'));
        expect(args['temperature'], equals(2.0));
        expect(args['topP'], equals(0.05));
        expect(args['maxTokens'], equals(2048));
      },
    );

    test('loadModel rejects non-gguf path', () async {
      final runtime = LLMRuntimeMobile();
      await expectLater(
        runtime.loadModel(const LLMConfig(modelPath: '/tmp/test.bin')),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
