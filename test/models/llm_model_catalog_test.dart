import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/models/llm_model_catalog.dart';

void main() {
  group('LLMModelCatalog', () {
    group('contains', () {
      test('returns true for bundled model ids', () {
        expect(LLMModelCatalog.contains('tinyllama'), isTrue);
        expect(LLMModelCatalog.contains('qwen-0.5b'), isTrue);
        expect(LLMModelCatalog.contains('qwen-1.5b'), isTrue);
        expect(LLMModelCatalog.contains('qwen-3.5-0.8b-q8_0'), isTrue);
      });

      test('returns true for custom model id', () {
        expect(LLMModelCatalog.contains('custom'), isTrue);
      });

      test('returns false for unknown id', () {
        expect(LLMModelCatalog.contains('unknown-model'), isFalse);
        expect(LLMModelCatalog.contains(''), isFalse);
        expect(LLMModelCatalog.contains('llama'), isFalse);
      });
    });

    group('getById', () {
      test('returns model for known id', () {
        final tinyllama = LLMModelCatalog.getById('tinyllama');
        expect(tinyllama, isNotNull);
        expect(tinyllama!.id, equals('tinyllama'));
        expect(tinyllama.name, equals('TinyLlama 1.1B'));
      });

      test('returns model for all bundled ids', () {
        for (final id in LLMModelCatalog.bundledIds) {
          final model = LLMModelCatalog.getById(id);
          expect(model, isNotNull, reason: 'Expected model for id: $id');
          expect(model!.id, equals(id));
        }
      });

      test('returns custom model for custom id', () {
        final custom = LLMModelCatalog.getById('custom');
        expect(custom, isNotNull);
        expect(custom!.id, equals('custom'));
        expect(custom.name, equals('自定义模型'));
      });

      test('returns null for unknown id', () {
        expect(LLMModelCatalog.getById('unknown'), isNull);
        expect(LLMModelCatalog.getById(''), isNull);
        expect(LLMModelCatalog.getById('llama-2'), isNull);
      });
    });

    group('bundledIds', () {
      test('contains expected bundled model ids', () {
        expect(LLMModelCatalog.bundledIds, contains('tinyllama'));
        expect(LLMModelCatalog.bundledIds, contains('qwen-0.5b'));
        expect(LLMModelCatalog.bundledIds, contains('qwen-1.5b'));
        expect(LLMModelCatalog.bundledIds, contains('qwen-3.5-0.8b-q8_0'));
        expect(LLMModelCatalog.bundledIds.length, equals(4));
      });
    });

    group('selectableIds', () {
      test('includes all bundled ids plus custom', () {
        expect(
          LLMModelCatalog.selectableIds,
          equals([...LLMModelCatalog.bundledIds, 'custom']),
        );
      });
    });

    group('defaultModelId', () {
      test('is tinyllama', () {
        expect(LLMModelCatalog.defaultModelId, equals('tinyllama'));
      });
    });
  });

  group('LLMModelOption', () {
    group('isBundled', () {
      test('returns true when assetPath is set', () {
        final model = LLMModelCatalog.getById('tinyllama')!;
        expect(model.isBundled, isTrue);
      });

      test('returns false when assetPath is null (custom model)', () {
        final model = LLMModelCatalog.getById('custom')!;
        expect(model.isBundled, isFalse);
      });
    });

    group('loadDropdownLabel', () {
      test('returns name and quantization for bundled model', () {
        final model = LLMModelCatalog.getById('tinyllama')!;
        expect(model.loadDropdownLabel, equals('TinyLlama 1.1B (Q4_K_M)'));
      });

      test('returns name and quantization for qwen model', () {
        final model = LLMModelCatalog.getById('qwen-1.5b')!;
        expect(model.loadDropdownLabel, equals('Qwen2.5 1.5B (Q4_0)'));
      });
    });

    group('settingsDropdownLabel', () {
      test('returns name and sizeLabel for bundled model', () {
        final model = LLMModelCatalog.getById('tinyllama')!;
        expect(model.settingsDropdownLabel, equals('TinyLlama 1.1B (638MB)'));
      });

      test('returns name and sizeLabel for qwen model', () {
        final model = LLMModelCatalog.getById('qwen-0.5b')!;
        expect(model.settingsDropdownLabel, equals('Qwen2.5 0.5B (~600MB)'));
      });
    });

    group('successName', () {
      test('returns name and quantization when quantization is not unknown', () {
        final model = LLMModelCatalog.getById('tinyllama')!;
        expect(model.successName, equals('TinyLlama 1.1B Q4_K_M'));
      });

      test('returns only name when quantization is unknown', () {
        final model = LLMModelCatalog.getById('custom')!;
        expect(model.successName, equals('自定义模型'));
      });
    });

    group('toSettingsConfig', () {
      test('returns correct config for bundled model', () {
        final model = LLMModelCatalog.getById('tinyllama')!;
        final config = model.toSettingsConfig();
        expect(config['name'], equals('TinyLlama 1.1B'));
        expect(config['size'], equals('638MB'));
        expect(config['quantization'], equals('Q4_K_M'));
        expect(config['asset'], equals(model.assetPath));
        expect(config['minMemory'], equals(1024));
      });

      test('returns null asset for custom model', () {
        final model = LLMModelCatalog.getById('custom')!;
        final config = model.toSettingsConfig();
        expect(config['asset'], isNull);
      });
    });

    group('bundled models have correct dropdown labels', () {
      test('all bundled models have non-empty loadDropdownLabel', () {
        for (final id in LLMModelCatalog.bundledIds) {
          final model = LLMModelCatalog.getById(id)!;
          expect(
            model.loadDropdownLabel.isNotEmpty,
            isTrue,
            reason: 'Expected non-empty loadDropdownLabel for $id',
          );
        }
      });

      test('all bundled models have non-empty settingsDropdownLabel', () {
        for (final id in LLMModelCatalog.bundledIds) {
          final model = LLMModelCatalog.getById(id)!;
          expect(
            model.settingsDropdownLabel.isNotEmpty,
            isTrue,
            reason: 'Expected non-empty settingsDropdownLabel for $id',
          );
        }
      });

      test('all bundled models have assetPath set', () {
        for (final id in LLMModelCatalog.bundledIds) {
          final model = LLMModelCatalog.getById(id)!;
          expect(
            model.assetPath,
            isNotNull,
            reason: 'Expected assetPath for $id',
          );
        }
      });

      test('all bundled models have positive minMemoryMB', () {
        for (final id in LLMModelCatalog.bundledIds) {
          final model = LLMModelCatalog.getById(id)!;
          expect(
            model.minMemoryMB,
            greaterThan(0),
            reason: 'Expected positive minMemoryMB for $id',
          );
        }
      });
    });
  });
}
