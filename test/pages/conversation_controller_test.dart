import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/core/conversation_controller.dart';
import 'package:model_loader/model_loader.dart';
import 'package:model_loader/models/conversation_entry.dart';
import 'package:model_loader/runtime/llm_runtime.dart';
import 'package:model_loader/utils/logger.dart';

class _RecordingLLMRuntime implements LLMRuntime {
  _RecordingLLMRuntime({
    required this.responses,
    this.failOnRequests = const <int>{},
  });

  final List<List<String>> responses;
  final Set<int> failOnRequests;
  final List<List<ChatMessage>> chatRequests = [];
  bool _isLoaded = true;
  int _requestIndex = 0;

  void setLoaded(bool value) => _isLoaded = value;

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
    chatRequests.add(List<ChatMessage>.from(messages));
    return responses[_requestIndex++].join();
  }

  @override
  Stream<String> chatStream(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  }) async* {
    final requestIndex = _requestIndex++;
    chatRequests.add(List<ChatMessage>.from(messages));
    if (failOnRequests.contains(requestIndex)) {
      throw StateError('stream failed');
    }
    final chunks = responses[requestIndex];
    for (final chunk in chunks) {
      yield chunk;
    }
  }

  @override
  Future<String> complete(String prompt, {GenerationConfig? config}) async =>
      '';

  @override
  Stream<String> completeStream(
    String prompt, {
    GenerationConfig? config,
  }) async* {}
}

class _ControllableLLMRuntime implements LLMRuntime {
  final StreamController<String> streamController = StreamController<String>();
  final List<List<ChatMessage>> chatRequests = [];
  bool _isLoaded = true;

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
  }) async => '';

  @override
  Stream<String> chatStream(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  }) {
    chatRequests.add(List<ChatMessage>.from(messages));
    return streamController.stream;
  }

  @override
  Future<String> complete(String prompt, {GenerationConfig? config}) async =>
      '';

  @override
  Stream<String> completeStream(
    String prompt, {
    GenerationConfig? config,
  }) async* {}
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

  setUp(() async {
    await ModelLoader.instance.configManager.setUISettings({});
  });

  group('ConversationController', () {
    test(
      'send includes previous user and assistant turns on later requests',
      () async {
        final runtime = _RecordingLLMRuntime(
          responses: const [
            ['Hi there'],
            ['You said hello'],
          ],
        );
        ModelLoader.instance.setLLMRuntime(runtime);
        final controller = ConversationController();

        await controller.send('Hello');
        await controller.send('What did I just say?');

        expect(runtime.chatRequests, hasLength(2));
        final secondRequest = runtime.chatRequests[1];
        expect(secondRequest, hasLength(3));
        expect(secondRequest[0].role, ChatRole.user);
        expect(secondRequest[0].content, 'Hello');
        expect(secondRequest[1].role, ChatRole.assistant);
        expect(secondRequest[1].content, 'Hi there');
        expect(secondRequest[2].role, ChatRole.user);
        expect(secondRequest[2].content, 'What did I just say?');

        controller.dispose();
      },
    );

    test('send prepends configured system prompt to chat history', () async {
      await ModelLoader.instance.configManager.setUISettings({
        'systemPrompt': '请直接回答，不要复读。',
      });

      final runtime = _RecordingLLMRuntime(
        responses: const [
          ['你好'],
        ],
      );
      ModelLoader.instance.setLLMRuntime(runtime);
      final controller = ConversationController();

      await controller.send('你好');

      expect(runtime.chatRequests, hasLength(1));
      final firstRequest = runtime.chatRequests.single;
      expect(firstRequest, hasLength(2));
      expect(firstRequest[0].role, ChatRole.system);
      expect(firstRequest[0].content, '请直接回答，不要复读。');
      expect(firstRequest[1].role, ChatRole.user);
      expect(firstRequest[1].content, '你好');

      controller.dispose();
    });

    test('failed turns are excluded from later chat history', () async {
      final runtime = _RecordingLLMRuntime(
        responses: const [
          [],
          ['Recovered'],
        ],
        failOnRequests: const {0},
      );
      ModelLoader.instance.setLLMRuntime(runtime);
      final controller = ConversationController();

      await controller.send('This fails');
      await controller.send('Next prompt');

      expect(runtime.chatRequests, hasLength(2));
      final secondRequest = runtime.chatRequests[1];
      expect(secondRequest, hasLength(1));
      expect(secondRequest.single.role, ChatRole.user);
      expect(secondRequest.single.content, 'Next prompt');

      controller.dispose();
    });

    test('dispose during active stream ignores later stream events', () async {
      final runtime = _ControllableLLMRuntime();
      ModelLoader.instance.setLLMRuntime(runtime);
      final controller = ConversationController();

      final sendFuture = controller.send('Hello');
      await Future<void>.delayed(Duration.zero);

      final entryCountBeforeDispose = controller.entries.length;
      controller.dispose();

      runtime.streamController.add('late chunk');
      await runtime.streamController.close();
      await sendFuture;

      expect(controller.entries.length, entryCountBeforeDispose);
    });

    test('reset clears entries and cancels active generation state', () async {
      final runtime = _ControllableLLMRuntime();
      ModelLoader.instance.setLLMRuntime(runtime);
      final controller = ConversationController();

      final sendFuture = controller.send('Hello');
      await Future<void>.delayed(Duration.zero);

      expect(controller.entries, isNotEmpty);
      expect(controller.isRunning, isTrue);

      controller.reset();

      expect(controller.entries, isEmpty);
      expect(controller.isRunning, isFalse);

      runtime.streamController.add('late chunk');
      await runtime.streamController.close();
      await sendFuture;

      expect(controller.entries, isEmpty);

      controller.dispose();
    });

    test('send with empty input adds error entry without calling LLM',
        () async {
      final runtime = _RecordingLLMRuntime(responses: const []);
      ModelLoader.instance.setLLMRuntime(runtime);
      final controller = ConversationController();

      await controller.send('');
      await controller.send('   ');

      expect(controller.entries, hasLength(2));
      expect(controller.entries[0].role, ConversationEntryRole.error);
      expect(controller.entries[0].text, '请输入内容');
      expect(controller.entries[1].role, ConversationEntryRole.error);
      expect(controller.entries[1].text, '请输入内容');
      expect(runtime.chatRequests, isEmpty);

      controller.dispose();
    });

    test('send when LLM not loaded adds error entry', () async {
      final runtime = _RecordingLLMRuntime(responses: const []);
      runtime.setLoaded(false);
      ModelLoader.instance.setLLMRuntime(runtime);
      final controller = ConversationController();

      await controller.send('Hello');

      expect(controller.entries, hasLength(1));
      expect(controller.entries[0].role, ConversationEntryRole.error);
      expect(controller.entries[0].text, contains('LLM'));
      expect(runtime.chatRequests, isEmpty);

      controller.dispose();
    });

    test('currentGenerationConfig clamps temperature and maxTokens', () async {
      final controller = ConversationController();

      // Default values
      await ModelLoader.instance.configManager.setUISettings({});
      var config = controller.currentGenerationConfig();
      expect(config.temperature, 0.7);
      expect(config.maxTokens, 2048);

      // Clamping temperature above 2.0
      await ModelLoader.instance.configManager
          .setUISettings({'temperature': 5.0});
      config = controller.currentGenerationConfig();
      expect(config.temperature, 2.0);

      // Clamping temperature below 0.0
      await ModelLoader.instance.configManager
          .setUISettings({'temperature': -1.0});
      config = controller.currentGenerationConfig();
      expect(config.temperature, 0.0);

      // Clamping maxTokens above 4096
      await ModelLoader.instance.configManager
          .setUISettings({'maxTokens': 9999});
      config = controller.currentGenerationConfig();
      expect(config.maxTokens, 4096);

      // Clamping maxTokens below 1
      await ModelLoader.instance.configManager
          .setUISettings({'maxTokens': 0});
      config = controller.currentGenerationConfig();
      expect(config.maxTokens, 1);

      controller.dispose();
    });

    test('finish event marks user entry as complete', () async {
      final runtime = _RecordingLLMRuntime(
        responses: const [
          ['Hi'],
        ],
      );
      ModelLoader.instance.setLLMRuntime(runtime);
      final controller = ConversationController();

      await controller.send('Hello');

      // Find user entry
      final userEntries = controller.entries
          .where((e) => e.role == ConversationEntryRole.user)
          .toList();
      expect(userEntries, hasLength(1));
      expect(userEntries[0].isComplete, isTrue);

      controller.dispose();
    });

    test('second send while first is running cancels first request', () async {
      final runtime = _ControllableLLMRuntime();
      ModelLoader.instance.setLLMRuntime(runtime);
      final controller = ConversationController();

      // Start first send
      final firstFuture = controller.send('First');
      await Future<void>.delayed(Duration.zero);

      // Start second send - should cancel first
      final secondFuture = controller.send('Second');
      await Future<void>.delayed(Duration.zero);

      // Complete second request
      runtime.streamController.add('Reply to second');
      await runtime.streamController.close();

      await firstFuture;
      await secondFuture;

      // Should have entries for both sends, but first was cancelled
      expect(controller.entries.length, greaterThanOrEqualTo(4));
      expect(controller.isRunning, isFalse);

      controller.dispose();
    });

    test('systemPrompt returns null for whitespace-only input', () async {
      await ModelLoader.instance.configManager
          .setUISettings({'systemPrompt': '   '});
      final runtime = _RecordingLLMRuntime(responses: const [
        ['ok'],
      ]);
      ModelLoader.instance.setLLMRuntime(runtime);
      final controller = ConversationController();

      await controller.send('test');

      // Whitespace-only system prompt should be excluded from history
      final request = runtime.chatRequests.single;
      expect(request.first.role, ChatRole.user);

      controller.dispose();
    });
  });
}
