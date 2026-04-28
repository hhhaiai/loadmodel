import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/model_loader.dart';
import 'package:model_loader/models/llm_model_catalog.dart';
import 'package:model_loader/pages/settings_page.dart';
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

  Future<void> pumpSettingsPage(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pump();
    await tester.pump(); // Second pump for post-frame callbacks
  }

  group('SettingsPage', () {
    testWidgets('renders without crash', (tester) async {
      await pumpSettingsPage(tester);
      expect(find.text('设置'), findsOneWidget);
    });

    testWidgets('shows LLM model settings section', (tester) async {
      await pumpSettingsPage(tester);
      expect(find.textContaining('LLM 模型设置'), findsOneWidget);
      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('Max Tokens'), findsOneWidget);
      expect(find.text('Context Length'), findsOneWidget);
      expect(find.text('系统提示词'), findsOneWidget);
    });

    testWidgets('shows Embedding model settings section', (tester) async {
      await pumpSettingsPage(tester);
      // Scroll down to find the Embedding section
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      expect(find.textContaining('Embedding'), findsWidgets);
    });

    testWidgets('shows platform info section', (tester) async {
      await pumpSettingsPage(tester);
      // Scroll down to find the platform section
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      expect(find.text('平台'), findsWidgets);
    });

    testWidgets('shows save button', (tester) async {
      await pumpSettingsPage(tester);
      // Scroll to bottom to find save button
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pump();
      expect(find.text('保存设置'), findsOneWidget);
    });

    testWidgets('LLM model dropdown shows selectable models', (tester) async {
      await pumpSettingsPage(tester);
      // The dropdown should show the current model label
      final defaultModel = LLMModelCatalog.getById(
        LLMModelCatalog.defaultModelId,
      );
      expect(defaultModel, isNotNull);
      expect(find.text(defaultModel!.settingsDropdownLabel), findsOneWidget);
    });

    testWidgets('system prompt field accepts input', (tester) async {
      await pumpSettingsPage(tester);
      final promptField = find.byType(TextField);
      expect(promptField, findsWidgets);

      // Enter text in the system prompt field (the multiline one)
      await tester.enterText(promptField.last, '你是一个助手');
      await tester.pump();
    });

    testWidgets('save button exists and has correct label', (tester) async {
      await pumpSettingsPage(tester);
      // Scroll down to find the save button
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pump();
      // The save button should exist with the correct label
      expect(find.text('保存设置'), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);
      // The button should be an ElevatedButton with a non-null onPressed
      final button = tester.widget<ElevatedButton>(
        find.byWidgetPredicate(
          (widget) => widget is ElevatedButton,
        ),
      );
      expect(button.onPressed, isNotNull);
    });
  });
}
