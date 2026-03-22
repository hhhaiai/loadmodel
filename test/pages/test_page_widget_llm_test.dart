import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/model_loader.dart';
import 'package:model_loader/models/model_loader_exception.dart';
import 'package:model_loader/pages/conversation_shell.dart';
import 'package:model_loader/runtime/llm_runtime.dart';
import 'package:model_loader/utils/logger.dart';

class _FakeLLMRuntime implements LLMRuntime {
  _FakeLLMRuntime({
    required bool isLoaded,
    this.streamChunks = const <String>[],
    this.throwOnStream = false,
    this.chunkDelay = Duration.zero,
  }) : _isLoaded = isLoaded;

  bool _isLoaded;
  final List<String> streamChunks;
  final bool throwOnStream;
  final Duration chunkDelay;

  @override
  bool get isLoaded => _isLoaded;

  @override
  LLMModelInfo? get loadedModel => null;

  @override
  Future<void> loadModel(LLMConfig config) async {
    _isLoaded = true;
  }

  @override
  Future<void> unloadModel() async {
    _isLoaded = false;
  }

  @override
  Future<String> chat(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  }) async {
    return streamChunks.join();
  }

  @override
  Stream<String> chatStream(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  }) async* {
    if (!_isLoaded) {
      throw StateError('llm model not loaded');
    }
    if (throwOnStream) {
      throw StateError('llm stream failed');
    }
    for (final chunk in streamChunks) {
      if (chunkDelay > Duration.zero) {
        await Future<void>.delayed(chunkDelay);
      }
      yield chunk;
    }
  }

  @override
  Future<String> complete(String prompt, {GenerationConfig? config}) async {
    return streamChunks.join();
  }

  @override
  Stream<String> completeStream(
    String prompt, {
    GenerationConfig? config,
  }) async* {
    if (throwOnStream) {
      throw StateError('llm complete stream failed');
    }
    for (final chunk in streamChunks) {
      if (chunkDelay > Duration.zero) {
        await Future<void>.delayed(chunkDelay);
      }
      yield chunk;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ModelLoader.initialize(
      config: const ModelLoaderConfig(
        enableRemoteModels: false,
        logLevel: LogLevel.warning,
        autoSelectRuntime: true,
      ),
    );
  });

  setUp(() {
    ModelLoader.instance.setLLMRuntime(
      _FakeLLMRuntime(isLoaded: true, streamChunks: const ['你', '好']),
    );
  });

  Future<void> pumpConversationShell(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ConversationShell()));
    await tester.pump();
  }

  group('ConversationShell LLM widget logic', () {
    testWidgets(
      'shows standardized not-loaded error when llm model is not loaded',
      (tester) async {
        ModelLoader.instance.setLLMRuntime(_FakeLLMRuntime(isLoaded: false));

        await pumpConversationShell(tester);
        await tester.enterText(
          find.byKey(const Key('conversation_input_field')),
          'llm input',
        );
        await tester.tap(find.byKey(const Key('conversation_send_button')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            '[${ModelLoaderErrorCode.MODEL_LOAD_FAILED.code}]',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('LLM 模型未加载'), findsOneWidget);
      },
    );

    testWidgets(
      'shows streamed response and finish marker when llm inference succeeds',
      (tester) async {
        ModelLoader.instance.setLLMRuntime(
          _FakeLLMRuntime(
            isLoaded: true,
            streamChunks: const ['你好', '，世界'],
            chunkDelay: const Duration(milliseconds: 20),
          ),
        );

        await pumpConversationShell(tester);
        await tester.enterText(
          find.byKey(const Key('conversation_input_field')),
          'llm success input',
        );
        await tester.tap(find.byKey(const Key('conversation_send_button')));

        await tester.pump(const Duration(milliseconds: 5));
        expect(find.textContaining('正在生成中'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 30));
        expect(find.textContaining('你好'), findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.textContaining('你好，世界'), findsOneWidget);
        expect(find.textContaining('[完成]'), findsNothing);
      },
    );

    testWidgets(
      'shows standardized inference-failed error when llm stream emits error',
      (tester) async {
        ModelLoader.instance.setLLMRuntime(
          _FakeLLMRuntime(isLoaded: true, throwOnStream: true),
        );

        await pumpConversationShell(tester);
        await tester.enterText(
          find.byKey(const Key('conversation_input_field')),
          'llm failure input',
        );
        await tester.tap(find.byKey(const Key('conversation_send_button')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            '[${ModelLoaderErrorCode.INFERENCE_FAILED.code}]',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('LLM 推理失败'), findsOneWidget);
        expect(find.textContaining('llm stream failed'), findsOneWidget);
      },
    );
  });
}
