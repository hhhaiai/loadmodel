import '../model_loader.dart';
import '../runtime/llm_runtime_llama.cpp.dart';
import '../runtime/llm_runtime_mobile.dart';
import '../runtime/onnx_runtime_flutter.dart';
import '../utils/logger.dart';

Future<void> bootstrapModelLoaderApp() async {
  await ModelLoader.initialize(
    config: const ModelLoaderConfig(
      enableRemoteModels: false,
      logLevel: LogLevel.info,
      autoSelectRuntime: true,
    ),
  );

  final ml = ModelLoader.instance;

  if (ml.platform.isMobile) {
    try {
      ml.setOCRRuntime(ONNXRuntimes.ocr);
      ml.setSTTRuntime(ONNXRuntimes.stt);
      ml.setEmbeddingRuntime(ONNXRuntimes.embedding);
      ml.setLLMRuntime(LLMRuntimeMobile());
      logger.info('Mobile runtimes configured: ONNX Runtime + local LLM channel');
    } catch (e) {
      logger.warning('Failed to configure mobile runtimes: $e');
    }
    return;
  }

  if (ml.platform.isMacOS || ml.platform.isDesktop) {
    try {
      ml.setOCRRuntime(ONNXRuntimes.ocr);
      ml.setSTTRuntime(ONNXRuntimes.stt);
      ml.setEmbeddingRuntime(ONNXRuntimes.embedding);
      logger.info('Desktop ONNX runtimes configured');
    } catch (e) {
      logger.warning('Failed to configure desktop ONNX runtimes: $e');
    }

    try {
      ml.setLLMRuntime(LLMRuntimeLlamaCpp());
      logger.info('Desktop LLM runtime configured: llama.cpp (bundled)');
    } catch (e) {
      logger.warning('Failed to configure desktop LLM runtime: $e');
    }
  }
}
