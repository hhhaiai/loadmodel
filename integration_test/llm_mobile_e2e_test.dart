import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:integration_test/integration_test.dart';
import 'package:model_loader/main.dart' as app;
import 'package:model_loader/model_loader.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<int> waitForAnyFinder(
    WidgetTester tester,
    List<Finder> finders, {
    Duration timeout = const Duration(seconds: 60),
    Duration step = const Duration(milliseconds: 200),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(step);
      for (var i = 0; i < finders.length; i++) {
        if (finders[i].evaluate().isNotEmpty) {
          return i;
        }
      }
    }
    fail('Timed out waiting for expected UI state');
  }

  testWidgets(
    'Android mobile LLM shows MODEL_LOAD_FAILED when not loaded',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle();

      await ModelLoader.instance.llm.unloadModel();

      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      await tester.pumpAndSettle();

      final input = find.byKey(const Key('conversation_input_field'));
      expect(input, findsOneWidget);
      await tester.enterText(input, '请简短介绍你自己');
      await tester.pumpAndSettle();

      final sendButton = find.byKey(const Key('test_send_button'));
      expect(sendButton, findsOneWidget);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('[MODEL_LOAD_FAILED]'), findsOneWidget);
      expect(find.textContaining('LLM 模型未加载'), findsOneWidget);
    },
    skip: !Platform.isAndroid,
  );

  testWidgets(
    'Android STT load shows MODEL_LOAD_FAILED when channel load call fails',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle();

      const channel = MethodChannel('com.modelloader/model_runtime');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'loadSTTModel') {
          throw PlatformException(
            code: 'LOAD_ERROR',
            message: 'Native runtime failed to load STT model',
          );
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
      });

      await tester.tap(find.byIcon(Icons.folder_open));
      await tester.pumpAndSettle();

      final loadTypeDropdown = find.byKey(const Key('load_model_type_dropdown'));
      expect(loadTypeDropdown, findsOneWidget);
      await tester.tap(loadTypeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('🎤 STT (语音识别)').last);
      await tester.pumpAndSettle();

      final loadButton = find.byKey(const Key('load_model_button'));
      expect(loadButton, findsOneWidget);
      await tester.tap(loadButton);
      await tester.pump();

      final sttLoadOutcome = await waitForAnyFinder(
        tester,
        [
          find.textContaining('[MODEL_LOAD_FAILED]'),
          find.textContaining('✅ STT 模型加载成功'),
        ],
        timeout: const Duration(minutes: 2),
      );

      if (sttLoadOutcome == 1) {
        fail('STT unexpectedly loaded successfully; expected channel load failure path for this test setup.');
      }

      expect(find.textContaining('[MODEL_LOAD_FAILED]'), findsOneWidget);
    },
    skip: !Platform.isAndroid,
  );

  testWidgets(
    'Android OCR load shows MODEL_LOAD_FAILED when channel load call fails',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle();

      const channel = MethodChannel('com.modelloader/model_runtime');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'loadOCRModel') {
          throw PlatformException(
            code: 'LOAD_ERROR',
            message: 'Native runtime failed to load OCR model',
          );
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
      });

      await tester.tap(find.byIcon(Icons.folder_open));
      await tester.pumpAndSettle();

      final loadTypeDropdown = find.byKey(const Key('load_model_type_dropdown'));
      expect(loadTypeDropdown, findsOneWidget);
      await tester.tap(loadTypeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('📷 OCR (文字识别)').last);
      await tester.pumpAndSettle();

      final loadButton = find.byKey(const Key('load_model_button'));
      expect(loadButton, findsOneWidget);
      await tester.tap(loadButton);
      await tester.pump();

      final ocrLoadOutcome = await waitForAnyFinder(
        tester,
        [
          find.textContaining('[MODEL_LOAD_FAILED]'),
          find.textContaining('✅ OCR 模型加载成功'),
        ],
        timeout: const Duration(minutes: 2),
      );

      if (ocrLoadOutcome == 1) {
        fail('OCR unexpectedly loaded successfully; expected channel load failure path for this test setup.');
      }

      expect(find.textContaining('[MODEL_LOAD_FAILED]'), findsOneWidget);
    },
    skip: !Platform.isAndroid,
  );

  testWidgets(
    'Android mobile LLM on-device flow works',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.folder_open));
      await tester.pumpAndSettle();

      final loadTypeDropdown = find.byKey(const Key('load_model_type_dropdown'));
      expect(loadTypeDropdown, findsOneWidget);
      await tester.tap(loadTypeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('💬 LLM (对话模型)').last);
      await tester.pumpAndSettle();

      final loadButton = find.byKey(const Key('load_model_button'));
      expect(loadButton, findsOneWidget);

      await tester.tap(loadButton);
      await tester.pump();

      final loadOutcome = await waitForAnyFinder(
        tester,
        [
          find.textContaining('✅ LLM 模型加载成功'),
          find.textContaining('[MODEL_LOAD_FAILED]'),
          find.textContaining('[MODEL_NOT_FOUND]'),
        ],
        timeout: const Duration(minutes: 5),
      );

      if (loadOutcome != 0) {
        final allStatus = find.byType(Text);
        final statusTexts = allStatus
            .evaluate()
            .map((e) => e.widget)
            .whereType<Text>()
            .map((t) => t.data ?? '')
            .where((t) => t.isNotEmpty)
            .toList();
        fail('LLM load did not succeed. Observed texts: ${statusTexts.join(' | ')}');
      }

      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      await tester.pumpAndSettle();

      final input = find.byKey(const Key('conversation_input_field'));
      expect(input, findsOneWidget);
      await tester.enterText(input, '请简短介绍你自己');
      await tester.pumpAndSettle();

      final sendButton = find.byKey(const Key('conversation_send_button'));
      expect(sendButton, findsOneWidget);
      await tester.tap(sendButton);
      await tester.pump();

      final chatOutcome = await waitForAnyFinder(
        tester,
        [
          find.textContaining('[完成]'),
          find.textContaining('[INFERENCE_FAILED]'),
        ],
        timeout: const Duration(minutes: 5),
      );

      if (chatOutcome != 0) {
        final allStatus = find.byType(Text);
        final statusTexts = allStatus
            .evaluate()
            .map((e) => e.widget)
            .whereType<Text>()
            .map((t) => t.data ?? '')
            .where((t) => t.isNotEmpty)
            .toList();
        fail('LLM chat failed. Observed texts: ${statusTexts.join(' | ')}');
      }

      expect(find.textContaining('🤖 回复:'), findsOneWidget);
    },
    skip: !Platform.isAndroid,
  );
}
