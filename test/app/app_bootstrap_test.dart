import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/app/app_bootstrap.dart';
import 'package:model_loader/model_loader.dart';
import 'package:model_loader/models/model_type.dart';
import 'package:model_loader/runtime/llm_runtime_llama.cpp.dart';

void main() {
  group('app_bootstrap', () {
    test('bootstrapModelLoaderApp initializes without error', () async {
      await bootstrapModelLoaderApp();
      expect(ModelLoader.instance, isNotNull);
    });

    test('bootstrapModelLoaderApp configures desktop llama runtime when available', () async {
      await bootstrapModelLoaderApp();

      final modelLoader = ModelLoader.instance;
      final llmConfig = modelLoader.getRecommendedRuntime(ModelType.llm);

      if (modelLoader.platform.isDesktop) {
        expect(llmConfig.runtime, 'llama.cpp');
        expect(modelLoader.llm, isA<LLMRuntimeLlamaCpp>());
      } else if (modelLoader.platform.isMobile) {
        expect(llmConfig.runtime, 'llama.cpp');
      }
    });
  });
}
