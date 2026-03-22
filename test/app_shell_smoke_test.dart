import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/app/app_shell.dart';
import 'package:model_loader/model_loader.dart';
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

  testWidgets('app shell renders navigation and test tab remains reachable', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();

    expect(find.text('状态'), findsAtLeastNWidgets(1));
    expect(find.text('加载'), findsAtLeastNWidgets(1));
    expect(find.text('对话'), findsAtLeastNWidgets(1));
    expect(find.text('测试'), findsAtLeastNWidgets(1));

    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('test_type_dropdown')), findsOneWidget);
  });
}
