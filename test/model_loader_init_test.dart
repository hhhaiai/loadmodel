import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/model_loader.dart';
import 'package:model_loader/models/model_type.dart';
import 'package:model_loader/utils/logger.dart';

void main() {
  group('ModelLoader P0 初始化与选择器', () {
    setUpAll(() async {
      await ModelLoader.initialize(
        config: const ModelLoaderConfig(
          enableRemoteModels: false,
          logLevel: LogLevel.warning,
          autoSelectRuntime: true,
        ),
      );
    });

    test('初始化后 SDK 可用', () {
      final ml = ModelLoader.instance;
      expect(ml.isInitialized, isTrue);
      expect(ml.models, isNotNull);
      expect(ml.configManager, isNotNull);
    });

    test('可执行 RuntimeSelector 并记录 SelectionReport', () {
      final ml = ModelLoader.instance;

      final report = ml.selectRuntimeForLoadType(
        type: ModelType.embedding,
        modelId: 'selector-test-model',
      );

      expect(report, isNotNull);
      expect(report!.requestId, isNotEmpty);
      expect(report.finalDecision.backend.name, isNotEmpty);
      expect(report.finalDecision.provider.name, isNotEmpty);
      expect(ml.lastSelectionReport, isNotNull);
      expect(ml.lastSelectionReport!.requestId, equals(report.requestId));
    });
  });
}
