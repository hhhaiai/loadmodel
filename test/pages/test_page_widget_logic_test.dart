import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/model_loader.dart';
import 'package:model_loader/models/model_loader_exception.dart';
import 'package:model_loader/pages/test_page.dart';
import 'package:model_loader/runtime/embedding_runtime.dart';
import 'package:model_loader/utils/logger.dart';

class _FakeEmbeddingRuntime implements EmbeddingRuntime {
  _FakeEmbeddingRuntime({required bool isLoaded, this.onGetEmbedding})
    : _isLoaded = isLoaded;

  final Future<EmbeddingResult> Function(String text)? onGetEmbedding;
  bool _isLoaded;

  @override
  bool get isLoaded => _isLoaded;

  @override
  Future<EmbeddingResult> getEmbedding(String text) async {
    if (!_isLoaded) {
      throw StateError('embedding model not loaded');
    }
    if (onGetEmbedding != null) {
      return onGetEmbedding!(text);
    }
    return const EmbeddingResult(
      embedding: [0.1, 0.2, 0.3, 0.4, 0.5],
      dimension: 5,
    );
  }

  @override
  Future<void> loadModel(EmbeddingConfig config) async {
    _isLoaded = true;
  }

  @override
  Future<void> unloadModel() async {
    _isLoaded = false;
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
    ModelLoader.instance.setEmbeddingRuntime(
      _FakeEmbeddingRuntime(isLoaded: true),
    );
  });

  Future<void> pumpTestPage(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TestPage()));
    await tester.pump();
  }

  group('TestPage embedding branch widget logic', () {
    testWidgets('shows validation message when input is empty', (tester) async {
      final ml = ModelLoader.instance;
      ml.setEmbeddingRuntime(_FakeEmbeddingRuntime(isLoaded: true));

      await pumpTestPage(tester);
      await tester.enterText(find.byKey(const Key('test_input_field')), '');
      await tester.tap(find.byKey(const Key('test_send_button')));
      await tester.pumpAndSettle();

      expect(find.text('请输入内容'), findsOneWidget);
    });

    testWidgets(
      'shows standardized not-loaded error when embedding model is not loaded',
      (tester) async {
        final ml = ModelLoader.instance;
        ml.setEmbeddingRuntime(_FakeEmbeddingRuntime(isLoaded: false));

        await pumpTestPage(tester);
        await tester.enterText(
          find.byKey(const Key('test_input_field')),
          'embedding input',
        );
        await tester.tap(find.byKey(const Key('test_send_button')));
        await tester.pumpAndSettle();

        final output = find.byType(SelectableText);
        expect(output, findsWidgets);
        expect(
          find.textContaining(
            '[${ModelLoaderErrorCode.MODEL_LOAD_FAILED.code}]',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Embedding 模型未加载'), findsOneWidget);
      },
    );

    testWidgets('shows embedding result when inference succeeds', (
      tester,
    ) async {
      final ml = ModelLoader.instance;
      ml.setEmbeddingRuntime(
        _FakeEmbeddingRuntime(
          isLoaded: true,
          onGetEmbedding: (text) async {
            expect(text, equals('embedding success input'));
            return EmbeddingResult(
              embedding: [1, 2, 3, 4, 5, 6].map((e) => e.toDouble()).toList(),
              dimension: 6,
            );
          },
        ),
      );

      await pumpTestPage(tester);
      await tester.enterText(
        find.byKey(const Key('test_input_field')),
        'embedding success input',
      );
      await tester.tap(find.byKey(const Key('test_send_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('✅ Embedding 结果:'), findsOneWidget);
      expect(find.textContaining('维度: 6'), findsOneWidget);
      expect(
        find.textContaining('前5个值: [1.0, 2.0, 3.0, 4.0, 5.0]'),
        findsOneWidget,
      );
    });

    testWidgets(
      'shows standardized inference-failed error when embedding inference throws',
      (tester) async {
        final ml = ModelLoader.instance;
        ml.setEmbeddingRuntime(
          _FakeEmbeddingRuntime(
            isLoaded: true,
            onGetEmbedding: (_) async {
              throw Exception('embedding failed');
            },
          ),
        );

        await pumpTestPage(tester);
        await tester.enterText(
          find.byKey(const Key('test_input_field')),
          'embedding failure input',
        );
        await tester.tap(find.byKey(const Key('test_send_button')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            '[${ModelLoaderErrorCode.INFERENCE_FAILED.code}]',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('EMBEDDING 推理失败'), findsOneWidget);
        expect(
          find.textContaining('原因: Exception: embedding failed'),
          findsOneWidget,
        );
      },
    );
  });
}
