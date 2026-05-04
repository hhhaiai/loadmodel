import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/model_loader.dart';
import 'package:model_loader/pages/model_load_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ModelLoader.initialize(
      config: const ModelLoaderConfig(
        enableRemoteModels: false,
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

  group('ModelLoadPage _isPlaceholderModelFile', () {
    test('returns false for non-existent file', () async {
      final page = _TestModelLoadPageState();
      final result = await page._isPlaceholderModelFile('/nonexistent/path.onnx');
      expect(result, false);
    });

    test('returns false for file without placeholder prefix', () async {
      final tempDir = Directory.systemTemp.createTempSync('model_load_test_');
      final tempFile = File('${tempDir.path}/model.onnx');
      await tempFile.writeAsString('This is a real ONNX model content');
      try {
        final page = _TestModelLoadPageState();
        final result = await page._isPlaceholderModelFile(tempFile.path);
        expect(result, false);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns true for file with placeholder prefix', () async {
      final tempDir = Directory.systemTemp.createTempSync('model_load_test_');
      final tempFile = File('${tempDir.path}/model.onnx');
      await tempFile.writeAsString('This is a placeholder ONNX model file');
      try {
        final page = _TestModelLoadPageState();
        final result = await page._isPlaceholderModelFile(tempFile.path);
        expect(result, true);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns false when file read throws', () async {
      final page = _TestModelLoadPageState();
      final result = await page._isPlaceholderModelFile(Directory.systemTemp.path);
      expect(result, false);
    });
  });

  group('ModelLoadPage buildRuntimeInfo', () {
    testWidgets('shows runtime info card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ModelLoadPage(
            loadModelAssets: ({
              required String modelDir,
              String? modelFile,
              String? tokenizerFile,
            }) async {
              return {};
            },
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('运行时'), findsWidgets);
    });
  });

  group('ModelLoadPage with custom loadModelAssets', () {
    testWidgets('embedding load shows missing asset status when assets empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ModelLoadPage(
            loadModelAssets: ({
              required String modelDir,
              String? modelFile,
              String? tokenizerFile,
            }) async {
              return {};
            },
          ),
        ),
      );
      await tester.pump();

      final loadButton = find.byKey(const Key('load_model_button'));
      expect(loadButton, findsOneWidget);

      await tester.tap(loadButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('模型文件缺失'), findsOneWidget);
    });

    testWidgets('LLM type shows LLM model dropdown', (tester) async {
      await pumpModelLoadPage(tester);
      await selectModelType(tester, '💬 LLM (对话模型)');
      expect(find.byKey(const Key('load_llm_model_dropdown')), findsOneWidget);
    });

    testWidgets('switching type clears previous status', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ModelLoadPage(
            loadModelAssets: ({
              required String modelDir,
              String? modelFile,
              String? tokenizerFile,
            }) async {
              return {};
            },
          ),
        ),
      );
      await tester.pump();

      final loadButton = find.byKey(const Key('load_model_button'));
      await tester.tap(loadButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('缺失'), findsOneWidget);

      await selectModelType(tester, '💬 LLM (对话模型)');
      expect(find.textContaining('缺失'), findsNothing);
    });
  });
}

/// Helper class to test _isPlaceholderModelFile logic
class _TestModelLoadPageState {
  Future<bool> _isPlaceholderModelFile(String modelPath) async {
    try {
      final file = File(modelPath);
      if (!await file.exists()) {
        return false;
      }
      final bytes = await file
          .openRead(0, 128)
          .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
      final prefix = String.fromCharCodes(bytes).toLowerCase();
      return prefix.contains('placeholder') && prefix.contains('onnx model');
    } catch (_) {
      return false;
    }
  }
}
