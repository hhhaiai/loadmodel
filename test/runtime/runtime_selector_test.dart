import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/models/model_manifest.dart';
import 'package:model_loader/models/model_type.dart';
import 'package:model_loader/runtime/runtime_selector.dart';

ModelManifestItem _llmModel({
  List<String> backendHints = const ['llama.cpp'],
  int contextLength = 2048,
  int minMemoryMB = 1024,
}) {
  return ModelManifestItem(
    id: 'qwen-3.5-0.8b-q8_0',
    type: ModelType.llm,
    version: '1.0.0',
    backendHints: backendHints,
    quantization: 'Q8_0',
    contextLength: contextLength,
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
    metadata: {'minMemoryMB': minMemoryMB},
  );
}

void main() {
  group('BackendType', () {
    test('has all expected types', () {
      expect(BackendType.values, contains(BackendType.llamaCpp));
      expect(BackendType.values, contains(BackendType.onnx));
      expect(BackendType.values, contains(BackendType.tflite));
      expect(BackendType.values, contains(BackendType.mediaPipe));
      expect(BackendType.values, contains(BackendType.vosk));
      expect(BackendType.values, contains(BackendType.whisperCpp));
    });

    test('name returns correct string', () {
      expect(BackendType.llamaCpp.name, equals('llamaCpp'));
      expect(BackendType.onnx.name, equals('onnx'));
    });
  });

  group('ProviderType', () {
    test('has all expected types', () {
      expect(ProviderType.values, contains(ProviderType.gpu));
      expect(ProviderType.values, contains(ProviderType.cpu));
    });
  });

  group('BackendCandidate', () {
    test('creates with required parameters', () {
      const candidate = BackendCandidate(
        backend: BackendType.llamaCpp,
        provider: ProviderType.gpu,
        accepted: true,
        reasons: [],
      );

      expect(candidate.backend, equals(BackendType.llamaCpp));
      expect(candidate.provider, equals(ProviderType.gpu));
      expect(candidate.accepted, isTrue);
    });

    test('creates with reasons', () {
      const candidate = BackendCandidate(
        backend: BackendType.onnx,
        provider: ProviderType.cpu,
        accepted: false,
        reasons: ['INSUFFICIENT_MEMORY', 'UNSUPPORTED_PLATFORM'],
      );

      expect(candidate.reasons.length, equals(2));
      expect(candidate.reasons, contains('INSUFFICIENT_MEMORY'));
    });

    test('toJson produces correct output', () {
      const candidate = BackendCandidate(
        backend: BackendType.llamaCpp,
        provider: ProviderType.gpu,
        accepted: true,
        reasons: ['OK'],
      );

      final json = candidate.toJson();
      expect(json['backend'], equals('llamaCpp'));
      expect(json['provider'], equals('gpu'));
      expect(json['accepted'], isTrue);
    });
  });

  group('DowngradeStep', () {
    test('creates with required parameters', () {
      const step = DowngradeStep(
        dimension: 'quantization',
        from: 'Q8_0',
        to: 'Q4_0',
      );

      expect(step.dimension, equals('quantization'));
      expect(step.from, equals('Q8_0'));
      expect(step.to, equals('Q4_0'));
    });

    test('toJson produces correct output', () {
      const step = DowngradeStep(
        dimension: 'contextLength',
        from: 4096,
        to: 2048,
      );

      final json = step.toJson();
      expect(json['dimension'], equals('contextLength'));
      expect(json['from'], equals(4096));
      expect(json['to'], equals(2048));
    });
  });

  group('FinalDecision', () {
    test('creates with required parameters', () {
      const decision = FinalDecision(
        backend: BackendType.llamaCpp,
        provider: ProviderType.gpu,
        contextLength: 4096,
        threads: 4,
        gpuLayers: 32,
      );

      expect(decision.backend, equals(BackendType.llamaCpp));
      expect(decision.provider, equals(ProviderType.gpu));
      expect(decision.contextLength, equals(4096));
      expect(decision.threads, equals(4));
      expect(decision.gpuLayers, equals(32));
    });

    test('creates with optional quantization', () {
      const decision = FinalDecision(
        backend: BackendType.llamaCpp,
        provider: ProviderType.cpu,
        quantization: 'Q4_0',
        contextLength: 2048,
        threads: 4,
        gpuLayers: 0,
      );

      expect(decision.quantization, equals('Q4_0'));
    });

    test('toJson produces correct output', () {
      const decision = FinalDecision(
        backend: BackendType.llamaCpp,
        provider: ProviderType.gpu,
        quantization: 'Q8_0',
        contextLength: 4096,
        threads: 4,
        gpuLayers: 32,
      );

      final json = decision.toJson();
      expect(json['backend'], equals('llamaCpp'));
      expect(json['provider'], equals('gpu'));
      expect(json['quantization'], equals('Q8_0'));
    });
  });

  group('SelectionReport', () {
    test('creates with required parameters', () {
      const decision = FinalDecision(
        backend: BackendType.llamaCpp,
        provider: ProviderType.gpu,
        contextLength: 4096,
        threads: 4,
        gpuLayers: 32,
      );

      const candidate = BackendCandidate(
        backend: BackendType.llamaCpp,
        provider: ProviderType.gpu,
        accepted: true,
        reasons: [],
      );

      const step = DowngradeStep(
        dimension: 'quantization',
        from: 'Q8_0',
        to: 'Q4_0',
      );

      final report = SelectionReport(
        requestId: 'test-request',
        candidates: const [candidate],
        downgradeSteps: const [step],
        finalDecision: decision,
      );

      expect(report.requestId, equals('test-request'));
      expect(report.candidates.length, equals(1));
      expect(report.downgradeSteps.length, equals(1));
      expect(report.finalDecision, equals(decision));
    });

    test('toJson produces correct output', () {
      const decision = FinalDecision(
        backend: BackendType.onnx,
        provider: ProviderType.cpu,
        contextLength: 0,
        threads: 2,
        gpuLayers: 0,
      );

      final report = SelectionReport(
        requestId: 'req-123',
        candidates: const [],
        downgradeSteps: const [],
        finalDecision: decision,
      );

      final json = report.toJson();
      expect(json['requestId'], equals('req-123'));
      expect(json['finalDecision'], isA<Map>());
    });
  });

  group('RuntimeSelector', () {
    test('allows llama.cpp on android when hinted', () {
      final selector = RuntimeSelector(
        platformName: 'android',
        availableMemoryMB: 4096,
        cpuCores: 8,
      );

      final report = selector.select(model: _llmModel());
      expect(report.finalDecision.backend, equals(BackendType.llamaCpp));
      expect(report.finalDecision.provider, equals(ProviderType.gpu));
    });

    test('falls back with downgrade steps when memory is insufficient', () {
      final selector = RuntimeSelector(
        platformName: 'android',
        availableMemoryMB: 512,
        cpuCores: 8,
      );

      final report = selector.select(
        model: _llmModel(contextLength: 8192, minMemoryMB: 4096),
      );

      expect(report.candidates.isNotEmpty, isTrue);
      expect(report.candidates.first.accepted, isFalse);
      expect(report.candidates.first.reasons, contains('INSUFFICIENT_MEMORY'));
      expect(report.downgradeSteps.any((s) => s.dimension == 'quantization'), isTrue);
      expect(report.downgradeSteps.any((s) => s.dimension == 'contextLength'), isTrue);
      expect(report.finalDecision.provider, equals(ProviderType.cpu));
      expect(report.finalDecision.gpuLayers, equals(0));
    });

    test('respects preferred backend/provider when specified', () {
      final selector = RuntimeSelector(
        platformName: 'android',
        availableMemoryMB: 4096,
        cpuCores: 8,
      );

      final report = selector.select(
        model: _llmModel(backendHints: const ['onnxruntime']),
        preferredBackend: 'llama.cpp',
        preferredProvider: 'cpu',
      );

      expect(report.finalDecision.backend, equals(BackendType.llamaCpp));
      expect(report.finalDecision.provider, equals(ProviderType.gpu));
    });

    test('selects embedding runtime correctly', () {
      final selector = RuntimeSelector(
        platformName: 'macOS',
        availableMemoryMB: 8192,
        cpuCores: 8,
      );

      final model = ModelManifestItem(
        id: 'bge-small',
        type: ModelType.embedding,
        version: '1.0.0',
        backendHints: const ['onnx'],
        requiredArtifacts: const [],
      );

      final report = selector.select(model: model);
      expect(report.finalDecision.backend, equals(BackendType.onnx));
    });

    test('selects OCR runtime correctly', () {
      final selector = RuntimeSelector(
        platformName: 'iOS',
        availableMemoryMB: 4096,
        cpuCores: 6,
      );

      final model = ModelManifestItem(
        id: 'easyocr',
        type: ModelType.ocr,
        version: '1.0.0',
        backendHints: const ['onnx'],
        requiredArtifacts: const [],
      );

      final report = selector.select(model: model);
      expect(report.finalDecision.backend, equals(BackendType.onnx));
    });
  });
}
