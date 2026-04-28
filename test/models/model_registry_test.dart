import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/models/model_registry.dart';
import 'package:model_loader/models/model_type.dart';

void main() {
  group('Model registry canonical IDs', () {
    test('contains qwen-3.5-0.8b-q8_0 with llamaCpp support', () {
      final model = BuiltInModels.getById('qwen-3.5-0.8b-q8_0');

      expect(model, isNotNull);
      expect(model!.id, equals('qwen-3.5-0.8b-q8_0'));
      expect(model.type, equals(ModelType.llm));
      expect(model.formats, contains('gguf'));
      expect(model.capability.supportedRuntimes, contains(RuntimeType.llamaCpp));
    });

    test('uses kebab-case qwen-0.5b id', () {
      final model = BuiltInModels.getById('qwen-0.5b');

      expect(model, isNotNull);
      expect(model!.id, equals('qwen-0.5b'));
    });

    test('does not expose legacy qwen0.5b id', () {
      final model = BuiltInModels.getById('qwen0.5b');
      expect(model, isNull);
    });
  });

  group('BuiltInModels', () {
    test('getAllModels returns all models', () {
      final models = BuiltInModels.getAllModels();
      expect(models, isNotEmpty);
      expect(models.length, greaterThan(5));
    });

    test('getByType returns LLM models', () {
      final llmModels = BuiltInModels.getByType(ModelType.llm);
      expect(llmModels, isNotEmpty);
      expect(llmModels.every((m) => m.type == ModelType.llm), isTrue);
    });

    test('getByType returns Embedding models', () {
      final embeddingModels = BuiltInModels.getByType(ModelType.embedding);
      expect(embeddingModels, isNotEmpty);
      expect(embeddingModels.every((m) => m.type == ModelType.embedding), isTrue);
    });

    test('getByType returns STT models', () {
      final sttModels = BuiltInModels.getByType(ModelType.stt);
      expect(sttModels, isNotEmpty);
      expect(sttModels.every((m) => m.type == ModelType.stt), isTrue);
    });

    test('getByType returns TTS models', () {
      final ttsModels = BuiltInModels.getByType(ModelType.tts);
      expect(ttsModels, isNotEmpty);
      expect(ttsModels.every((m) => m.type == ModelType.tts), isTrue);
    });

    test('getByType returns OCR models', () {
      final ocrModels = BuiltInModels.getByType(ModelType.ocr);
      expect(ocrModels, isNotEmpty);
      expect(ocrModels.every((m) => m.type == ModelType.ocr), isTrue);
    });

    test('getByType returns empty for unknown type', () {
      final unknownModels = BuiltInModels.getByType(ModelType.classification);
      expect(unknownModels, isEmpty);
    });

    test('getSupportedForCurrentPlatform returns models with runtimes', () {
      final models = BuiltInModels.getSupportedForCurrentPlatform();
      expect(models, isNotEmpty);
      expect(models.every((m) => m.capability.supportedRuntimes.isNotEmpty), isTrue);
    });

    test('getById returns null for unknown id', () {
      final model = BuiltInModels.getById('unknown-model');
      expect(model, isNull);
    });
  });

  group('ModelCapability', () {
    test('creates with required parameters', () {
      const capability = ModelCapability(
        supportedRuntimes: [RuntimeType.onnx],
      );
      expect(capability.supportedRuntimes, [RuntimeType.onnx]);
      expect(capability.supportsQuantization, isFalse);
      expect(capability.minMemoryMB, equals(512));
      expect(capability.recommendedMemoryMB, equals(1024));
    });

    test('creates with all parameters', () {
      const capability = ModelCapability(
        supportedRuntimes: [RuntimeType.llamaCpp, RuntimeType.onnx],
        supportsQuantization: true,
        minMemoryMB: 1024,
        recommendedMemoryMB: 2048,
      );
      expect(capability.supportsQuantization, isTrue);
      expect(capability.minMemoryMB, equals(1024));
      expect(capability.recommendedMemoryMB, equals(2048));
    });
  });

  group('ModelDefinition', () {
    test('creates with required parameters', () {
      const definition = ModelDefinition(
        id: 'test-model',
        name: 'Test Model',
        type: ModelType.llm,
        formats: ['gguf'],
        capability: ModelCapability(supportedRuntimes: [RuntimeType.llamaCpp]),
      );
      expect(definition.id, 'test-model');
      expect(definition.name, 'Test Model');
      expect(definition.type, ModelType.llm);
      expect(definition.formats, ['gguf']);
      expect(definition.defaultConfig, isNull);
    });

    test('creates with optional defaultConfig', () {
      const definition = ModelDefinition(
        id: 'test-model',
        name: 'Test Model',
        type: ModelType.llm,
        formats: ['gguf'],
        capability: ModelCapability(supportedRuntimes: [RuntimeType.llamaCpp]),
        defaultConfig: {'max_tokens': 2048},
      );
      expect(definition.defaultConfig, isNotNull);
      expect(definition.defaultConfig!['max_tokens'], 2048);
    });
  });

  group('RuntimeType', () {
    test('has all expected values', () {
      expect(RuntimeType.values, contains(RuntimeType.onnx));
      expect(RuntimeType.values, contains(RuntimeType.llamaCpp));
      expect(RuntimeType.values, contains(RuntimeType.tflite));
      expect(RuntimeType.values, contains(RuntimeType.mediaPipe));
      expect(RuntimeType.values, contains(RuntimeType.vosk));
      expect(RuntimeType.values, contains(RuntimeType.whisperCpp));
    });
  });
}
