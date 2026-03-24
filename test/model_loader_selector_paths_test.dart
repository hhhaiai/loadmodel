import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/model_loader.dart';
import 'package:model_loader/models/model_manifest.dart';
import 'package:model_loader/models/model_type.dart';
import 'package:model_loader/runtime/runtime_selector.dart';
import 'package:model_loader/utils/logger.dart';

void main() {
  group('ModelLoader selector paths', () {
    setUpAll(() async {
      await ModelLoader.initialize(
        config: const ModelLoaderConfig(
          enableRemoteModels: false,
          logLevel: LogLevel.warning,
          autoSelectRuntime: true,
        ),
      );
    });

    test('returns null for unsupported load type', () {
      final ml = ModelLoader.instance;
      final report = ml.selectRuntimeForLoadType(type: ModelType.ocr);
      expect(report, isNull);
    });

    test('embedding load type defaults to onnx hint', () {
      final ml = ModelLoader.instance;
      final report = ml.selectRuntimeForLoadType(type: ModelType.embedding);
      expect(report, isNotNull);
      expect(report!.finalDecision.backend, equals(BackendType.onnx));
    });

    test('llm load type defaults to llama.cpp hint', () {
      final ml = ModelLoader.instance;
      final report = ml.selectRuntimeForLoadType(type: ModelType.llm);
      expect(report, isNotNull);
      expect(report!.finalDecision.backend, equals(BackendType.llamaCpp));
    });

    test('manifest model with unsupported platform still returns report', () {
      final ml = ModelLoader.instance;
      final manifestModel = ModelManifestItem(
        id: 'platform-gated-model',
        type: ModelType.llm,
        version: '1.0.0',
        backendHints: const ['llama.cpp'],
        requiredArtifacts: const [
          Artifact(
            name: 'model.gguf',
            role: ArtifactRole.model,
            format: 'gguf',
            path: 'model.gguf',
            size: 1,
            sha256: 'dummy',
          ),
        ],
        platforms: const ['definitely-unsupported-platform'],
      );

      final report = ml.selectRuntimeForManifestModel(model: manifestModel);
      expect(report.requestId, isNotEmpty);
      expect(report.finalDecision.backend, equals(BackendType.onnx));
      expect(report.finalDecision.provider, equals(ProviderType.cpu));
    });

    test('preferred backend/provider values are accepted', () {
      final ml = ModelLoader.instance;
      final manifestModel = ModelManifestItem(
        id: 'preferred-provider-model',
        type: ModelType.llm,
        version: '1.0.0',
        backendHints: const ['onnxruntime'],
        requiredArtifacts: const [
          Artifact(
            name: 'model.gguf',
            role: ArtifactRole.model,
            format: 'gguf',
            path: 'model.gguf',
            size: 1,
            sha256: 'dummy',
          ),
        ],
      );

      final report = ml.selectRuntimeForManifestModel(
        model: manifestModel,
        preferredBackend: 'llama.cpp',
        preferredProvider: 'cpu',
      );

      expect(report.finalDecision.backend, equals(BackendType.llamaCpp));
      expect(report.finalDecision.provider, isNotNull);
    });

    test('resolveLLMLoadConfig applies selection decision to load config', () {
      final ml = ModelLoader.instance;
      final resolved = ml.resolveLLMLoadConfig(
        modelPath: '/tmp/qwen.gguf',
        modelId: 'qwen-1.5b',
        uiSettings: const {
          'contextLength': 4096,
          'maxTokens': 4096,
          'temperature': 1.1,
        },
        availableMemoryMB: 1024,
        cpuCores: 6,
      );

      final report = resolved.selectionReport;
      expect(report, isNotNull);
      expect(report!.finalDecision.contextLength, equals(2048));
      expect(resolved.config.contextLength, equals(2048));
      expect(resolved.config.maxTokens, equals(2048));
      expect(resolved.config.threads, equals(5));
      expect(resolved.config.temperature, equals(1.1));
    });
  });
}
