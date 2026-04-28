import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/model_loader.dart';
import 'package:model_loader/pages/status_page.dart';
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

  Future<void> pumpStatusPage(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: StatusPage()));
    await tester.pump();
  }

  group('StatusPage', () {
    testWidgets('renders without crash', (tester) async {
      await pumpStatusPage(tester);
      expect(find.text('状态'), findsOneWidget);
    });

    testWidgets('shows platform info section', (tester) async {
      await pumpStatusPage(tester);
      expect(find.textContaining('平台信息'), findsOneWidget);
      expect(find.text('平台'), findsOneWidget);
      expect(find.text('移动端'), findsOneWidget);
      expect(find.text('桌面端'), findsOneWidget);
    });

    testWidgets('shows runtime status section', (tester) async {
      await pumpStatusPage(tester);
      expect(find.textContaining('运行时状态'), findsOneWidget);
      expect(find.text('LLM'), findsOneWidget);
      expect(find.text('OCR'), findsOneWidget);
      expect(find.text('TTS'), findsOneWidget);
      expect(find.text('STT'), findsOneWidget);
      expect(find.text('Embedding'), findsOneWidget);
    });

    testWidgets('shows directory section', (tester) async {
      await pumpStatusPage(tester);
      expect(find.textContaining('目录'), findsOneWidget);
      expect(find.text('缓存'), findsOneWidget);
      expect(find.text('自定义'), findsOneWidget);
    });

    testWidgets('shows runtime loaded state', (tester) async {
      await pumpStatusPage(tester);
      // All runtimes start as stubs (not loaded)
      expect(find.textContaining('未加载'), findsWidgets);
    });

    testWidgets('shows correct platform name', (tester) async {
      await pumpStatusPage(tester);
      final ml = ModelLoader.instance;
      // Platform name should be shown in uppercase
      expect(
        find.text(ml.platform.name.toUpperCase()),
        findsOneWidget,
      );
    });
  });
}
