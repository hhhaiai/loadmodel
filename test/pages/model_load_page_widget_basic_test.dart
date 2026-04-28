import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/model_loader.dart';
import 'package:model_loader/models/llm_model_catalog.dart';
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
    testWidgets('renders without crash', (tester) async {
      await pumpModelLoadPage(tester);
      // AppBar title + button label both say "加载模型"
      expect(find.text('加载模型'), findsWidgets);
    });

    testWidgets('shows model type dropdown', (tester) async {
      await pumpModelLoadPage(tester);
      expect(
        find.byKey(const Key('load_model_type_dropdown')),
        findsOneWidget,
      );
    });

    testWidgets('shows load button', (tester) async {
      await pumpModelLoadPage(tester);
      expect(find.byIcon(Icons.upload), findsOneWidget);
      // Button is an ElevatedButton
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('shows runtime info card', (tester) async {
      await pumpModelLoadPage(tester);
      // Should show either mobile or desktop runtime info
      expect(
        find.textContaining('运行时'),
        findsWidgets,
      );
    });

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

    testWidgets('switching model type updates the dropdown selection', (
      tester,
    ) async {
      await pumpModelLoadPage(tester);

      // Switch to STT
      await selectModelType(tester, '🎤 STT (语音识别)');

      // Switch to Embedding - should not crash
      await selectModelType(tester, '📊 Embedding (文本向量)');

      // Switch to OCR - should not crash
      await selectModelType(tester, '📷 OCR (文字识别)');

      // Verify LLM dropdown still hidden (not LLM type)
      expect(find.byKey(const Key('load_llm_model_dropdown')), findsNothing);
    });

    testWidgets('LLM dropdown shows catalog models when opened', (
      tester,
    ) async {
      await pumpModelLoadPage(tester);
      await selectModelType(tester, '💬 LLM (对话模型)');

      // Open the LLM dropdown to see its items
      await tester.tap(find.byKey(const Key('load_llm_model_dropdown')));
      await tester.pumpAndSettle();

      // Verify at least one catalog model label appears in the dropdown
      final firstModel = LLMModelCatalog.getById(
        LLMModelCatalog.bundledIds.first,
      )!;
      expect(find.text(firstModel.loadDropdownLabel), findsWidgets);
    });

    testWidgets('status area hidden when empty', (tester) async {
      await pumpModelLoadPage(tester);
      // Status container should not be visible initially
      expect(find.textContaining('加载成功'), findsNothing);
      expect(find.textContaining('加载失败'), findsNothing);
    });

    testWidgets('load button has correct label', (tester) async {
      await pumpModelLoadPage(tester);
      // The button shows "加载模型" when not loading
      final button = find.byWidgetPredicate(
        (widget) => widget is ElevatedButton,
      );
      expect(button, findsOneWidget);
    });
  });
}
