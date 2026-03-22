import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/model_loader.dart';
import 'package:model_loader/pages/model_load_page.dart';
import 'package:model_loader/utils/logger.dart';

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

  Future<void> pumpModelLoadPage(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ModelLoadPage()));
    await tester.pump();
  }

  Future<void> selectModelType(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const Key('load_model_type_dropdown')));
    await tester.pumpAndSettle();
    final optionFinder = find.text(label);
    expect(optionFinder, findsOneWidget);
    await tester.tap(optionFinder);
    await tester.pumpAndSettle();
  }

  group('ModelLoadPage basic widget behavior', () {
    testWidgets('shows LLM model dropdown only when model type is llm', (
      tester,
    ) async {
      await pumpModelLoadPage(tester);

      expect(find.byKey(const Key('load_llm_model_dropdown')), findsNothing);

      await selectModelType(tester, '💬 LLM (对话模型)');
      expect(find.byKey(const Key('load_llm_model_dropdown')), findsOneWidget);

      await selectModelType(tester, '📊 Embedding (文本向量)');
      expect(find.byKey(const Key('load_llm_model_dropdown')), findsNothing);
    });

    testWidgets('tts load branch shows runtime unavailable status message', (
      tester,
    ) async {
      await pumpModelLoadPage(tester);
      await selectModelType(tester, '🔊 TTS (语音合成)');

      await tester.tap(find.byKey(const Key('load_model_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('[RUNTIME_NOT_AVAILABLE]'), findsOneWidget);
      expect(find.textContaining('TTS 运行时当前不可用'), findsOneWidget);
    });

    testWidgets('changing model type clears previous status message', (
      tester,
    ) async {
      await pumpModelLoadPage(tester);
      await selectModelType(tester, '🔊 TTS (语音合成)');

      await tester.tap(find.byKey(const Key('load_model_button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('TTS 运行时当前不可用'), findsOneWidget);

      await selectModelType(tester, '📊 Embedding (文本向量)');
      expect(find.textContaining('TTS 运行时当前不可用'), findsNothing);
    });
  });
}
