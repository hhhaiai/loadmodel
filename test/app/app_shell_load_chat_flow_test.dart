import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/app/app_shell.dart';
import 'package:model_loader/model_loader.dart';
import 'package:model_loader/models/llm_model_catalog.dart';
import 'package:model_loader/pages/conversation_shell.dart';
import 'package:model_loader/pages/model_load_page.dart';
import 'package:model_loader/pages/models_page.dart';
import 'package:model_loader/pages/settings_page.dart';
import 'package:model_loader/pages/status_page.dart';
import 'package:model_loader/pages/test_page.dart';
import 'package:model_loader/runtime/llm_runtime.dart';
import 'package:model_loader/utils/logger.dart';

class _RecordingLLMRuntime implements LLMRuntime {
  _RecordingLLMRuntime({required this.responseChunks});

  final List<String> responseChunks;
  final List<LLMConfig> loadRequests = <LLMConfig>[];
  final List<List<ChatMessage>> chatRequests = <List<ChatMessage>>[];

  bool _isLoaded = false;

  @override
  bool get isLoaded => _isLoaded;

  @override
  LLMModelInfo? get loadedModel => loadRequests.isEmpty
      ? null
      : LLMModelInfo(
          name: loadRequests.last.modelPath.split('/').last,
          path: loadRequests.last.modelPath,
          contextLength: loadRequests.last.contextLength,
        );

  @override
  Future<void> loadModel(LLMConfig config) async {
    loadRequests.add(config);
    _isLoaded = true;
  }

  @override
  Future<void> unloadModel() async {
    _isLoaded = false;
  }

  @override
  Future<String> complete(String prompt, {GenerationConfig? config}) async {
    return responseChunks.join();
  }

  @override
  Stream<String> completeStream(
    String prompt, {
    GenerationConfig? config,
  }) async* {
    yield* Stream<String>.fromIterable(responseChunks);
  }

  @override
  Future<String> chat(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  }) async {
    chatRequests.add(List<ChatMessage>.from(messages));
    return responseChunks.join();
  }

  @override
  Stream<String> chatStream(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  }) async* {
    if (!_isLoaded) {
      throw StateError('llm model not loaded');
    }
    chatRequests.add(List<ChatMessage>.from(messages));
    yield* Stream<String>.fromIterable(responseChunks);
  }
}

class _LlmCase {
  const _LlmCase({required this.modelId, required this.responseText});

  final String modelId;
  final String responseText;

  LLMModelOption get model => LLMModelCatalog.getById(modelId)!;

  String get label => model.loadDropdownLabel;

  String get assetPath => model.assetPath!;

  String get expectedRelativeCachePath => assetPath.replaceFirst('assets/', '');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testCacheDir = Directory.systemTemp.createTempSync(
    'app_shell_load_chat_flow_test_',
  );

  const llmCases = <_LlmCase>[
    _LlmCase(modelId: 'tinyllama', responseText: 'tinyllama-ready'),
    _LlmCase(modelId: 'qwen-0.5b', responseText: 'qwen-0.5b-ready'),
    _LlmCase(modelId: 'qwen-1.5b', responseText: 'qwen-1.5b-ready'),
    _LlmCase(modelId: 'qwen-3.5-0.8b-q8_0', responseText: 'qwen-3.5-ready'),
  ];

  final fakeAssetPaths = <String, String>{};

  setUpAll(() async {
    for (final testCase in llmCases) {
      final file = File(
        '${testCacheDir.path}/${testCase.expectedRelativeCachePath}',
      );
      await file.parent.create(recursive: true);
      await file.writeAsString('GGUF-${testCase.responseText}');
      fakeAssetPaths[testCase.assetPath] = file.path;
    }

    await ModelLoader.initialize(
      config: ModelLoaderConfig(
        enableRemoteModels: false,
        logLevel: LogLevel.warning,
        autoSelectRuntime: true,
        modelCacheDir: testCacheDir.path,
      ),
    );
  });

  tearDownAll(() async {
    if (testCacheDir.existsSync()) {
      testCacheDir.deleteSync(recursive: true);
    }
  });

  Future<void> pumpAppShell(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          pages: <Widget>[
            const StatusPage(),
            ModelLoadPage(
              resolveAssetPath: (assetPath) async => fakeAssetPaths[assetPath],
            ),
            const ConversationShell(),
            const TestPage(),
            const ModelsPage(),
            const SettingsPage(),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openLoadTab(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.folder_open));
    await tester.pumpAndSettle();
  }

  Future<void> openConversationTab(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await tester.pumpAndSettle();
  }

  Future<void> selectDropdownValue(
    WidgetTester tester, {
    required Key dropdownKey,
    required String label,
  }) async {
    await tester.tap(find.byKey(dropdownKey));
    await tester.pumpAndSettle();

    final optionFinder = find.text(label).last;
    expect(optionFinder, findsOneWidget);
    await tester.tap(optionFinder);
    await tester.pumpAndSettle();
  }

  Future<void> pumpUntilText(
    WidgetTester tester,
    String text, {
    int maxPumps = 40,
    Duration step = const Duration(milliseconds: 50),
  }) async {
    for (var i = 0; i < maxPumps; i++) {
      await tester.pump(step);
      if (find.textContaining(text).evaluate().isNotEmpty) {
        return;
      }
    }
    final visibleTexts = tester
        .widgetList<Text>(find.byType(Text, skipOffstage: false))
        .map((widget) => widget.data)
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(' | ');
    fail('Timed out waiting for text: $text\nVisible texts: $visibleTexts');
  }

  setUp(() async {
    await ModelLoader.instance.configManager.setUISettings(<String, dynamic>{});
  });

  group('AppShell load and chat flow', () {
    for (final testCase in llmCases) {
      testWidgets('loads ${testCase.label} and streams a conversation reply', (
        tester,
      ) async {
        final runtime = _RecordingLLMRuntime(
          responseChunks: <String>[testCase.responseText],
        );
        ModelLoader.instance.setLLMRuntime(runtime);

        await pumpAppShell(tester);
        await openLoadTab(tester);
        await selectDropdownValue(
          tester,
          dropdownKey: const Key('load_model_type_dropdown'),
          label: '💬 LLM (对话模型)',
        );
        await selectDropdownValue(
          tester,
          dropdownKey: const Key('load_llm_model_dropdown'),
          label: testCase.label,
        );

        await tester.tap(find.byKey(const Key('load_model_button')));
        await pumpUntilText(tester, 'LLM 模型加载成功');

        expect(find.textContaining('LLM 模型加载成功'), findsOneWidget);
        expect(runtime.loadRequests, hasLength(1));
        expect(runtime.isLoaded, isTrue);
        expect(
          runtime.loadRequests.single.modelPath.replaceAll('\\', '/'),
          contains(testCase.expectedRelativeCachePath),
        );

        await openConversationTab(tester);
        await tester.enterText(
          find.byKey(const Key('conversation_input_field')),
          'app flow prompt',
        );
        await tester.tap(find.byKey(const Key('conversation_send_button')));
        await pumpUntilText(tester, testCase.responseText);

        expect(find.text('app flow prompt'), findsOneWidget);
        expect(find.textContaining(testCase.responseText), findsOneWidget);
        expect(runtime.chatRequests, hasLength(1));
        expect(runtime.chatRequests.single.last.content, 'app flow prompt');
      });
    }
  });
}
