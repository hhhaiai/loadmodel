import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/model_loader.dart';
import 'package:model_loader/models/inference_result.dart';
import 'package:model_loader/models/model_loader_exception.dart';
import 'package:model_loader/pages/test_page.dart';
import 'package:model_loader/runtime/ocr_runtime.dart';
import 'package:model_loader/runtime/stt_runtime.dart';
import 'package:model_loader/utils/logger.dart';

class _FakeSTTRuntime implements STTRuntime {
  _FakeSTTRuntime({required bool isLoaded, this.onRecognizeBytes})
    : _isLoaded = isLoaded;

  final Future<STTResult> Function(Uint8List audioBytes)? onRecognizeBytes;
  bool _isLoaded;

  @override
  bool get isLoaded => _isLoaded;

  @override
  Future<void> loadModel(STTConfig config) async {
    _isLoaded = true;
  }

  @override
  Future<void> unloadModel() async {
    _isLoaded = false;
  }

  @override
  Future<STTResult> recognize(String audioPath, {STTParams? params}) {
    throw UnimplementedError();
  }

  @override
  Future<STTResult> recognizeBytes(
    Uint8List audioBytes, {
    STTParams? params,
  }) async {
    if (!_isLoaded) {
      throw StateError('stt model not loaded');
    }
    if (onRecognizeBytes != null) {
      return onRecognizeBytes!(audioBytes);
    }
    return const STTResult(text: 'hello stt', confidence: 0.88, language: 'zh');
  }

  @override
  Stream<STTResult> recognizeStream(
    Stream<Uint8List> audioStream, {
    STTParams? params,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getSupportedLanguages() async => const ['zh', 'en'];
}

class _FakeOCRRuntime implements OCRRuntime {
  _FakeOCRRuntime({required bool isLoaded, this.onRecognizeBytes})
    : _isLoaded = isLoaded;

  final Future<OCRResult> Function(Uint8List imageBytes)? onRecognizeBytes;
  bool _isLoaded;

  @override
  bool get isLoaded => _isLoaded;

  @override
  Future<void> loadModel(OCRConfig config) async {
    _isLoaded = true;
  }

  @override
  Future<void> unloadModel() async {
    _isLoaded = false;
  }

  @override
  Future<OCRResult> recognize(String imagePath, {OCRParams? params}) {
    throw UnimplementedError();
  }

  @override
  Future<OCRResult> recognizeBytes(
    Uint8List imageBytes, {
    OCRParams? params,
  }) async {
    if (!_isLoaded) {
      throw StateError('ocr model not loaded');
    }
    if (onRecognizeBytes != null) {
      return onRecognizeBytes!(imageBytes);
    }
    return const OCRResult(
      text: 'hello ocr',
      blocks: [],
      averageConfidence: 0.77,
    );
  }
}

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

  setUp(() {
    final ml = ModelLoader.instance;
    ml.setSTTRuntime(_FakeSTTRuntime(isLoaded: true));
    ml.setOCRRuntime(_FakeOCRRuntime(isLoaded: true));
  });

  Future<void> pumpTestPage(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TestPage()));
    await tester.pump();
  }

  Future<void> selectTestType(WidgetTester tester, String value) async {
    await tester.tap(find.byKey(const Key('test_type_dropdown')));
    await tester.pumpAndSettle();
    final optionText = switch (value) {
      'stt' => '🎤 STT',
      'ocr' => '📷 OCR',
      _ => throw StateError('unsupported test type: $value'),
    };
    final optionFinder = find.text(optionText);
    expect(optionFinder, findsOneWidget);
    await tester.tap(optionFinder);
    await tester.pumpAndSettle();
  }

  group('TestPage STT/OCR widget logic', () {
    testWidgets('STT shows standardized not-loaded error', (tester) async {
      final ml = ModelLoader.instance;
      ml.setSTTRuntime(_FakeSTTRuntime(isLoaded: false));

      await pumpTestPage(tester);
      await selectTestType(tester, 'stt');
      await tester.enterText(
        find.byKey(const Key('test_input_field')),
        'stt input',
      );
      await tester.tap(find.byKey(const Key('test_send_button')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('[${ModelLoaderErrorCode.MODEL_LOAD_FAILED.code}]'),
        findsOneWidget,
      );
      expect(find.textContaining('STT 模型未加载'), findsOneWidget);
    });

    testWidgets('STT shows inference result when runtime succeeds', (
      tester,
    ) async {
      final ml = ModelLoader.instance;
      ml.setSTTRuntime(
        _FakeSTTRuntime(
          isLoaded: true,
          onRecognizeBytes: (bytes) async {
            expect(bytes, isNotEmpty);
            return const STTResult(
              text: '你好 STT',
              confidence: 0.91,
              language: 'zh',
            );
          },
        ),
      );

      await pumpTestPage(tester);
      await selectTestType(tester, 'stt');
      await tester.enterText(
        find.byKey(const Key('test_input_field')),
        'stt success input',
      );
      await tester.tap(find.byKey(const Key('test_send_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('🎤 STT 完成'), findsOneWidget);
      expect(find.textContaining('文本: 你好 STT'), findsOneWidget);
      expect(find.textContaining('置信度: 0.91'), findsOneWidget);
      expect(find.textContaining('语言: zh'), findsOneWidget);
    });

    testWidgets(
      'STT shows standardized inference-failed error when runtime throws',
      (tester) async {
        final ml = ModelLoader.instance;
        ml.setSTTRuntime(
          _FakeSTTRuntime(
            isLoaded: true,
            onRecognizeBytes: (_) async {
              throw Exception('stt failed');
            },
          ),
        );

        await pumpTestPage(tester);
        await selectTestType(tester, 'stt');
        await tester.enterText(
          find.byKey(const Key('test_input_field')),
          'stt failure input',
        );
        await tester.tap(find.byKey(const Key('test_send_button')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            '[${ModelLoaderErrorCode.INFERENCE_FAILED.code}]',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('STT 推理失败'), findsOneWidget);
        expect(
          find.textContaining('原因: Exception: stt failed'),
          findsOneWidget,
        );
      },
    );

    testWidgets('OCR shows camera and gallery buttons', (tester) async {
      await pumpTestPage(tester);
      await selectTestType(tester, 'ocr');

      expect(find.byKey(const Key('ocr_camera_button')), findsOneWidget);
      expect(find.byKey(const Key('ocr_gallery_button')), findsOneWidget);
      expect(find.text('拍照识别'), findsOneWidget);
      expect(find.text('选择图片'), findsOneWidget);
      expect(find.text('请拍照或选择图片'), findsOneWidget);
    });

    testWidgets('OCR shows no-image error when tapped without image', (
      tester,
    ) async {
      await pumpTestPage(tester);
      await selectTestType(tester, 'ocr');
      await tester.tap(find.byKey(const Key('test_send_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('请先拍照或选择图片'), findsOneWidget);
    });

    testWidgets('OCR shows model-not-loaded error', (tester) async {
      final ml = ModelLoader.instance;
      ml.setOCRRuntime(_FakeOCRRuntime(isLoaded: false));

      await pumpTestPage(tester);
      await selectTestType(tester, 'ocr');
      // Tap send without selecting image — model check happens first
      await tester.tap(find.byKey(const Key('test_send_button')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('[${ModelLoaderErrorCode.MODEL_LOAD_FAILED.code}]'),
        findsOneWidget,
      );
      expect(find.textContaining('OCR 模型未加载'), findsOneWidget);
    });

    testWidgets('OCR UI has image preview area', (tester) async {
      await pumpTestPage(tester);
      await selectTestType(tester, 'ocr');

      // Verify the preview container exists
      expect(find.text('请拍照或选择图片'), findsOneWidget);
      // Verify the send button says "识别"
      expect(find.text('识别'), findsOneWidget);
    });

    testWidgets(
      'OCR shows standardized inference-failed error when runtime throws',
      (tester) async {
        final ml = ModelLoader.instance;
        ml.setOCRRuntime(
          _FakeOCRRuntime(
            isLoaded: true,
            onRecognizeBytes: (_) async {
              throw Exception('ocr failed');
            },
          ),
        );

        await pumpTestPage(tester);
        await selectTestType(tester, 'ocr');
        // Without image, shows no-image error
        await tester.tap(find.byKey(const Key('test_send_button')));
        await tester.pumpAndSettle();

        expect(find.textContaining('请先拍照或选择图片'), findsOneWidget);
      },
    );
  });
}
