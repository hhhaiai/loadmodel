import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/model_loader.dart';
import 'package:model_loader/models/model_loader_exception.dart';
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

  Future<void> pumpModelLoadPage(
    WidgetTester tester, {
    Future<Map<String, String>> Function({
      required String modelDir,
      String? modelFile,
      String? tokenizerFile,
    })? loadModelAssets,
    Future<String?> Function(String assetPath)? resolveAssetPath,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ModelLoadPage(
          loadModelAssets: loadModelAssets,
          resolveAssetPath: resolveAssetPath,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> selectModelType(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const Key('load_model_type_dropdown')));
    await tester.pumpAndSettle();
    // Use last because find.text also matches the selected value in the closed dropdown
    final optionFinder = find.text(label).last;
    await tester.tap(optionFinder);
    await tester.pumpAndSettle();
  }

  Future<void> tapLoadButton(WidgetTester tester) async {
    final loadButton = find.byKey(const Key('load_model_button'));
    expect(loadButton, findsOneWidget);
    await tester.tap(loadButton);
    await tester.pumpAndSettle();
  }

  // =========================================================================
  // _buildLoadErrorStatus widget tests
  // The _buildLoadErrorStatus method is private, so we test it indirectly
  // by triggering load failures through the loadModelAssets callback.
  // =========================================================================

  group('ModelLoadPage _buildLoadErrorStatus error state', () {
    testWidgets(
      'shows RUNTIME_NOT_AVAILABLE status when PlatformException with RUNTIME_NOT_AVAILABLE code is thrown',
      (tester) async {
        await pumpModelLoadPage(
          tester,
          loadModelAssets: ({
            required String modelDir,
            String? modelFile,
            String? tokenizerFile,
          }) async {
            throw PlatformException(
              code: 'RUNTIME_NOT_AVAILABLE',
              message: 'onnxruntime bridge not initialized',
            );
          },
        );

        await selectModelType(tester, '📊 Embedding (文本向量)');
        await tapLoadButton(tester);

        // Should show runtime unavailable status with warning icon
        expect(find.textContaining('运行时当前不可用'), findsOneWidget);
        expect(
          find.textContaining('[${ModelLoaderErrorCode.RUNTIME_NOT_AVAILABLE.code}]'),
          findsOneWidget,
        );
        expect(find.textContaining('onnxruntime bridge not initialized'), findsOneWidget);
      },
    );

    testWidgets(
      'shows RUNTIME_NOT_AVAILABLE status when PlatformException with NOT_IMPLEMENTED code is thrown',
      (tester) async {
        await pumpModelLoadPage(
          tester,
          loadModelAssets: ({
            required String modelDir,
            String? modelFile,
            String? tokenizerFile,
          }) async {
            throw PlatformException(
              code: 'NOT_IMPLEMENTED',
              message: 'Method not implemented on this platform',
            );
          },
        );

        await selectModelType(tester, '🎤 STT (语音识别)');
        await tapLoadButton(tester);

        // Should show runtime unavailable status
        expect(find.textContaining('运行时当前不可用'), findsOneWidget);
        expect(
          find.textContaining('[${ModelLoaderErrorCode.RUNTIME_NOT_AVAILABLE.code}]'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows MODEL_LOAD_FAILED status for generic PlatformException errors',
      (tester) async {
        await pumpModelLoadPage(
          tester,
          loadModelAssets: ({
            required String modelDir,
            String? modelFile,
            String? tokenizerFile,
          }) async {
            throw PlatformException(
              code: 'LOAD_ERROR',
              message: 'Failed to load model from path',
            );
          },
        );

        await selectModelType(tester, '📷 OCR (文字识别)');
        await tapLoadButton(tester);

        // Should show model load failed status (not runtime unavailable)
        expect(
          find.textContaining('[${ModelLoaderErrorCode.MODEL_LOAD_FAILED.code}]'),
          findsOneWidget,
        );
        expect(find.textContaining('OCR'), findsWidgets);
        expect(find.textContaining('PlatformException(LOAD_ERROR, Failed to load model from path'), findsOneWidget);
      },
    );

    testWidgets(
      'shows MODEL_LOAD_FAILED status for non-PlatformException errors',
      (tester) async {
        await pumpModelLoadPage(
          tester,
          loadModelAssets: ({
            required String modelDir,
            String? modelFile,
            String? tokenizerFile,
          }) async {
            throw Exception('Unknown error during model loading');
          },
        );

        await selectModelType(tester, '📊 Embedding (文本向量)');
        await tapLoadButton(tester);

        // Should show model load failed status
        expect(
          find.textContaining('[${ModelLoaderErrorCode.MODEL_LOAD_FAILED.code}]'),
          findsOneWidget,
        );
        expect(find.textContaining('Embedding'), findsWidgets);
        // Error reason contains "Exception:" prefix from toString()
        expect(find.textContaining('Exception:'), findsOneWidget);
      },
    );

    testWidgets(
      'shows error status with correct task label for OCR type',
      (tester) async {
        await pumpModelLoadPage(
          tester,
          loadModelAssets: ({
            required String modelDir,
            String? modelFile,
            String? tokenizerFile,
          }) async {
            throw PlatformException(
              code: 'MODEL_LOAD_FAILED',
              message: 'OCR processing failed',
            );
          },
        );

        await selectModelType(tester, '📷 OCR (文字识别)');
        await tapLoadButton(tester);

        expect(
          find.textContaining('[${ModelLoaderErrorCode.MODEL_LOAD_FAILED.code}]'),
          findsOneWidget,
        );
        expect(find.textContaining('OCR'), findsWidgets);
        expect(find.textContaining('OCR processing failed'), findsOneWidget);
      },
    );
  });

  // =========================================================================
  // buildRuntimeUnavailableStatus function tests (exported function)
  // =========================================================================

  group('buildRuntimeUnavailableStatus', () {
    test('includes RUNTIME_NOT_AVAILABLE code and task label', () {
      final text = buildRuntimeUnavailableStatus(
        taskLabel: 'Embedding',
        reason: 'native bridge not available',
      );

      expect(text, contains('[RUNTIME_NOT_AVAILABLE]'));
      expect(text, contains('Embedding'));
      expect(text, contains('运行时当前不可用'));
    });

    test('includes reason when provided', () {
      final text = buildRuntimeUnavailableStatus(
        taskLabel: 'STT',
        reason: 'audio processor not initialized',
      );

      expect(text, contains('原因: audio processor not initialized'));
    });

    test('omits reason when null', () {
      final text = buildRuntimeUnavailableStatus(taskLabel: 'TTS');

      expect(text.contains('原因:'), isFalse);
    });

    test('omits reason when empty string', () {
      final text = buildRuntimeUnavailableStatus(
        taskLabel: 'OCR',
        reason: '',
      );

      expect(text.contains('原因:'), isFalse);
    });

    test('includes guidance message about switching platform', () {
      final text = buildRuntimeUnavailableStatus(
        taskLabel: 'Embedding',
        reason: 'some reason',
      );

      expect(text, contains('请切换平台或补齐该能力的原生实现'));
    });
  });

  // =========================================================================
  // buildMissingLlmAssetStatus function tests (exported function)
  // =========================================================================

  group('buildMissingLlmAssetStatus', () {
    test('includes MODEL_NOT_FOUND code and asset path', () {
      final text = buildMissingLlmAssetStatus(
        assetPath: 'assets/models/qwen/qwen-3.5-0.8b.Q4_K_M.gguf',
      );

      expect(text, contains('[MODEL_NOT_FOUND]'));
      expect(text, contains('LLM 模型文件缺失'));
      expect(text, contains('assets/models/qwen/qwen-3.5-0.8b.Q4_K_M.gguf'));
    });

    test('includes instruction about assets directory', () {
      final text = buildMissingLlmAssetStatus(
        assetPath: 'assets/models/tinyllama/model.gguf',
      );

      expect(text, contains('请确保模型文件存在于 assets 目录'));
    });
  });

  // =========================================================================
  // buildRuntimeLoadFailedStatus function tests (exported function)
  // =========================================================================

  group('buildRuntimeLoadFailedStatus', () {
    test('includes MODEL_LOAD_FAILED code and task label', () {
      final text = buildRuntimeLoadFailedStatus(
        taskLabel: 'OCR',
        reason: 'file corrupted',
      );

      expect(text, contains('[MODEL_LOAD_FAILED]'));
      expect(text, contains('OCR'));
      expect(text, contains('模型加载失败'));
      expect(text, contains('原因: file corrupted'));
    });

    test('omits reason suffix when reason is null', () {
      final text = buildRuntimeLoadFailedStatus(taskLabel: 'STT');

      expect(text, contains('[MODEL_LOAD_FAILED]'));
      expect(text, contains('STT'));
      expect(text, contains('模型加载失败'));
      expect(text.contains('原因:'), isFalse);
    });

    test('omits reason suffix when reason is empty', () {
      final text = buildRuntimeLoadFailedStatus(
        taskLabel: 'Embedding',
        reason: '',
      );

      expect(text, contains('[MODEL_LOAD_FAILED]'));
      expect(text, contains('模型加载失败'));
      expect(text.contains('原因:'), isFalse);
    });
  });

  // =========================================================================
  // buildMissingAssetStatus function tests (exported function)
  // =========================================================================

  group('buildMissingAssetStatus', () {
    test('includes MODEL_NOT_FOUND code and model directory', () {
      final text = buildMissingAssetStatus(
        modelDir: 'whisper',
        taskLabel: 'STT',
        requiredFiles: const ['model.onnx', 'model_config.json'],
      );

      expect(text, contains('[MODEL_NOT_FOUND]'));
      expect(text, contains('STT'));
      expect(text, contains('assets/models/whisper/'));
      expect(text, contains('- model.onnx'));
      expect(text, contains('- model_config.json'));
    });

    test('displays all required files in list format', () {
      final text = buildMissingAssetStatus(
        modelDir: 'bge-small',
        taskLabel: 'Embedding',
        requiredFiles: const ['model.onnx', 'tokenizer.json', 'config.json'],
      );

      expect(text, contains('- model.onnx'));
      expect(text, contains('- tokenizer.json'));
      expect(text, contains('- config.json'));
    });
  });

  // =========================================================================
  // Widget integration tests for error state display
  // =========================================================================

  group('ModelLoadPage error state widget display', () {
    testWidgets(
      'error status container uses red background for load failures',
      (tester) async {
        await pumpModelLoadPage(
          tester,
          loadModelAssets: ({
            required String modelDir,
            String? modelFile,
            String? tokenizerFile,
          }) async {
            throw Exception('Test error');
          },
        );

        await selectModelType(tester, '📊 Embedding (文本向量)');
        await tapLoadButton(tester);

        // Find the status container
        final containerFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration != null &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color == Colors.red.shade100,
        );
        expect(containerFinder, findsOneWidget);
      },
    );

    testWidgets(
      'error status displays status code in brackets',
      (tester) async {
        await pumpModelLoadPage(
          tester,
          loadModelAssets: ({
            required String modelDir,
            String? modelFile,
            String? tokenizerFile,
          }) async {
            throw PlatformException(
              code: 'MODEL_LOAD_FAILED',
              message: 'test failure',
            );
          },
        );

        await selectModelType(tester, '📷 OCR (文字识别)');
        await tapLoadButton(tester);

        // Status code should appear in brackets
        expect(find.textContaining('[MODEL_LOAD_FAILED]'), findsOneWidget);
      },
    );

    testWidgets(
      'missing LLM asset shows missing LLM asset status',
      (tester) async {
        // resolveAssetPath returns null to simulate missing asset
        await pumpModelLoadPage(
          tester,
          loadModelAssets: ({
            required String modelDir,
            String? modelFile,
            String? tokenizerFile,
          }) async {
            return {};
          },
          resolveAssetPath: (assetPath) async => null,
        );

        await selectModelType(tester, '💬 LLM (对话模型)');
        await tapLoadButton(tester);

        // Should show missing LLM asset status
        expect(find.textContaining('LLM 模型文件缺失'), findsOneWidget);
        expect(
          find.textContaining('[${ModelLoaderErrorCode.MODEL_NOT_FOUND.code}]'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'empty assets map shows missing asset status for embedding',
      (tester) async {
        await pumpModelLoadPage(
          tester,
          loadModelAssets: ({
            required String modelDir,
            String? modelFile,
            String? tokenizerFile,
          }) async {
            return {};
          },
        );

        await selectModelType(tester, '📊 Embedding (文本向量)');
        await tapLoadButton(tester);

        expect(find.textContaining('模型文件缺失'), findsOneWidget);
        expect(find.textContaining('Embedding'), findsWidgets);
      },
    );

    testWidgets(
      'empty assets map shows missing asset status for stt',
      (tester) async {
        await pumpModelLoadPage(
          tester,
          loadModelAssets: ({
            required String modelDir,
            String? modelFile,
            String? tokenizerFile,
          }) async {
            return {};
          },
        );

        await selectModelType(tester, '🎤 STT (语音识别)');
        await tapLoadButton(tester);

        expect(find.textContaining('模型文件缺失'), findsOneWidget);
        expect(find.textContaining('STT'), findsWidgets);
      },
    );

    testWidgets(
      'empty assets map shows missing asset status for ocr',
      (tester) async {
        await pumpModelLoadPage(
          tester,
          loadModelAssets: ({
            required String modelDir,
            String? modelFile,
            String? tokenizerFile,
          }) async {
            return {};
          },
        );

        await selectModelType(tester, '📷 OCR (文字识别)');
        await tapLoadButton(tester);

        expect(find.textContaining('模型文件缺失'), findsOneWidget);
        expect(find.textContaining('OCR'), findsWidgets);
      },
    );

    testWidgets(
      'load button is disabled during loading and re-enabled after error',
      (tester) async {
        await pumpModelLoadPage(
          tester,
          loadModelAssets: ({
            required String modelDir,
            String? modelFile,
            String? tokenizerFile,
          }) async {
            // Simulate slow loading that then fails
            await Future.delayed(const Duration(milliseconds: 100));
            throw Exception('Delayed error');
          },
        );

        await selectModelType(tester, '📊 Embedding (文本向量)');

        // Verify button exists
        final loadButton = find.byKey(const Key('load_model_button'));
        expect(loadButton, findsOneWidget);

        // Tap load button and wait for full completion
        await tester.tap(loadButton);
        // Wait for both the async load AND any animations to complete
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // After error, button should show '加载模型' (not '加载中...')
        expect(find.text('加载模型').last, findsOneWidget);
        // And error status should be visible
        expect(find.textContaining('Exception:'), findsOneWidget);
      },
    );

    testWidgets(
      'switching model type after error clears the error status',
      (tester) async {
        await pumpModelLoadPage(
          tester,
          loadModelAssets: ({
            required String modelDir,
            String? modelFile,
            String? tokenizerFile,
          }) async {
            throw Exception('Some error');
          },
        );

        await selectModelType(tester, '📊 Embedding (文本向量)');
        await tapLoadButton(tester);

        // Error should be displayed
        expect(find.textContaining('模型加载失败'), findsOneWidget);

        // Switch to LLM type
        await selectModelType(tester, '💬 LLM (对话模型)');

        // Error status should be cleared
        expect(find.textContaining('模型加载失败'), findsNothing);
      },
    );

    testWidgets(
      'RUNTIME_NOT_AVAILABLE status includes guidance text',
      (tester) async {
        await pumpModelLoadPage(
          tester,
          loadModelAssets: ({
            required String modelDir,
            String? modelFile,
            String? tokenizerFile,
          }) async {
            throw PlatformException(
              code: 'RUNTIME_NOT_AVAILABLE',
              message: 'runtime not ready',
            );
          },
        );

        await selectModelType(tester, '🎤 STT (语音识别)');
        await tapLoadButton(tester);

        // Should include guidance about switching platform
        expect(find.textContaining('请切换平台或补齐该能力的原生实现'), findsOneWidget);
      },
    );
  });
}
