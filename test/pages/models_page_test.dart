import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/model_loader.dart';
import 'package:model_loader/pages/models_page.dart';
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

  Future<void> pumpModelsPage(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ModelsPage()));
    await tester.pump();
  }

  group('ModelsPage', () {
    testWidgets('renders without crash', (tester) async {
      await pumpModelsPage(tester);
      expect(find.text('支持的模型'), findsOneWidget);
    });

    testWidgets('shows model cards from registry', (tester) async {
      await pumpModelsPage(tester);
      final models = ModelLoader.instance.getSupportedModels();
      // At least one model should be shown
      expect(models.isNotEmpty, isTrue);
      // First model name should appear
      expect(find.text(models.first.name), findsOneWidget);
    });

    testWidgets('each model card shows format and memory info', (
      tester,
    ) async {
      await pumpModelsPage(tester);
      // At least one format text should exist
      expect(find.textContaining('格式:'), findsWidgets);
      // At least one memory text should exist
      expect(find.textContaining('最低内存:'), findsWidgets);
    });

    testWidgets('tapping a model shows detail dialog', (tester) async {
      await pumpModelsPage(tester);
      final models = ModelLoader.instance.getSupportedModels();
      if (models.isEmpty) return;

      // Tap the first model
      await tester.tap(find.text(models.first.name));
      await tester.pumpAndSettle();

      // Dialog should show model details
      expect(find.textContaining('类型:'), findsOneWidget);
      expect(find.textContaining('推荐内存:'), findsOneWidget);
      expect(find.textContaining('支持量化:'), findsOneWidget);
    });

    testWidgets('dialog close button works', (tester) async {
      await pumpModelsPage(tester);
      final models = ModelLoader.instance.getSupportedModels();
      if (models.isEmpty) return;

      await tester.tap(find.text(models.first.name));
      await tester.pumpAndSettle();

      // Tap close button
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed - the detail text should be gone
      expect(find.textContaining('推荐内存:'), findsNothing);
    });
  });
}
