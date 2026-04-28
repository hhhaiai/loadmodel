import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/models/model_info.dart';
import 'package:model_loader/models/model_type.dart';
import 'package:model_loader/models/model_manifest.dart';

void main() {
  group('ModelInfo', () {
    test('creates with required parameters', () {
      final info = ModelInfo(
        id: 'test-model',
        name: 'Test Model',
        type: ModelType.llm,
        format: 'gguf',
        size: 1000,
      );

      expect(info.id, equals('test-model'));
      expect(info.name, equals('Test Model'));
      expect(info.type, equals(ModelType.llm));
      expect(info.format, equals('gguf'));
      expect(info.size, equals(1000));
    });

    test('creates with all parameters', () {
      final info = ModelInfo(
        id: 'test-model',
        name: 'Test Model',
        type: ModelType.embedding,
        format: 'onnx',
        version: '1.0.0',
        size: 1000000,
        downloadUrl: 'https://example.com/model.onnx',
        sha256: 'abc123',
        description: 'A test model',
        recommendedQuantizations: ['Q4_0', 'Q8_0'],
      );

      expect(info.version, equals('1.0.0'));
      expect(info.size, equals(1000000));
      expect(info.downloadUrl, equals('https://example.com/model.onnx'));
      expect(info.sha256, equals('abc123'));
      expect(info.recommendedQuantizations, contains('Q4_0'));
    });

    test('formattedSize formats bytes correctly', () {
      final info = ModelInfo(
        id: 'test',
        name: 'Test',
        type: ModelType.llm,
        format: 'gguf',
        size: 1024 * 1024,
      );

      expect(info.formattedSize, contains('MB'));
    });

    test('fromJson parses complete data', () {
      final json = {
        'id': 'test-model',
        'name': 'Test Model',
        'type': 'embedding',
        'format': 'onnx',
        'version': '2.0.0',
        'size': 2000000,
      };

      final info = ModelInfo.fromJson(json);

      expect(info.id, equals('test-model'));
      expect(info.type, equals(ModelType.embedding));
      expect(info.format, equals('onnx'));
      expect(info.version, equals('2.0.0'));
    });

    test('toJson produces correct output', () {
      final info = ModelInfo(
        id: 'test-model',
        name: 'Test Model',
        type: ModelType.stt,
        format: 'onnx',
        version: '1.0.0',
        size: 1000,
      );

      final json = info.toJson();

      expect(json['id'], equals('test-model'));
      expect(json['type'], equals('stt'));
      expect(json['format'], equals('onnx'));
    });
  });

  group('PlatformRequirements', () {
    test('creates with required parameters', () {
      final req = PlatformRequirements(
        minMemoryMB: 1024,
      );

      expect(req.minMemoryMB, equals(1024));
      expect(req.supportsGpu, isFalse);
      expect(req.supportedPlatforms, contains('android'));
    });

    test('creates with all parameters', () {
      final req = PlatformRequirements(
        minMemoryMB: 2048,
        supportsGpu: true,
        supportedPlatforms: ['ios', 'android'],
      );

      expect(req.supportsGpu, isTrue);
      expect(req.supportedPlatforms, equals(['ios', 'android']));
    });

    test('fromJson parses complete data', () {
      final json = {
        'minMemoryMB': 4096,
        'supportsGpu': true,
        'platforms': ['ios', 'android'],
      };

      final req = PlatformRequirements.fromJson(json);

      expect(req.minMemoryMB, equals(4096));
      expect(req.supportsGpu, isTrue);
    });

    test('toJson produces correct output', () {
      final req = PlatformRequirements(
        minMemoryMB: 2048,
        supportsGpu: true,
      );

      final json = req.toJson();

      expect(json['minMemoryMB'], equals(2048));
      expect(json['supportsGpu'], isTrue);
    });
  });

  group('ModelManifest', () {
    test('creates with required parameters', () {
      final manifest = ModelManifest(
        manifestSchemaVersion: '1.0.0',
        manifestVersion: '1.0.0',
        generatedAt: '2024-01-01T00:00:00Z',
        models: [
          ModelManifestItem(
            id: 'test-model',
            type: ModelType.llm,
            version: '1.0.0',
            requiredArtifacts: [],
          ),
        ],
      );

      expect(manifest.models.length, equals(1));
      expect(manifest.models.first.id, equals('test-model'));
    });

    test('fromJson parses complete data', () {
      final json = {
        'manifestSchemaVersion': '1.0.0',
        'manifestVersion': '1.0.0',
        'generatedAt': '2024-01-01T00:00:00Z',
        'models': [
          {
            'id': 'test-model',
            'type': 'embedding',
            'version': '1.0.0',
            'requiredArtifacts': [],
          }
        ]
      };

      final manifest = ModelManifest.fromJson(json);

      expect(manifest.models.length, equals(1));
      expect(manifest.models.first.type, equals(ModelType.embedding));
    });
  });

  group('ModelManifestItem', () {
    test('creates with required parameters', () {
      final item = ModelManifestItem(
        id: 'test-model',
        type: ModelType.llm,
        version: '1.0.0',
        requiredArtifacts: const [],
      );

      expect(item.id, equals('test-model'));
      expect(item.type, equals(ModelType.llm));
      expect(item.version, equals('1.0.0'));
    });

    test('creates with all parameters', () {
      final item = ModelManifestItem(
        id: 'test-model',
        type: ModelType.embedding,
        version: '2.0.0',
        backendHints: const ['onnx'],
        quantization: 'Q4_0',
        contextLength: 512,
        requiredArtifacts: const [],
        metadata: {'key': 'value'},
      );

      expect(item.backendHints, equals(['onnx']));
      expect(item.quantization, equals('Q4_0'));
      expect(item.contextLength, equals(512));
      expect(item.metadata, containsPair('key', 'value'));
    });
  });

  group('Artifact', () {
    test('creates with required parameters', () {
      const artifact = Artifact(
        name: 'model.bin',
        role: ArtifactRole.model,
        format: 'bin',
        path: 'model.bin',
        size: 1000,
        sha256: 'abc123',
      );

      expect(artifact.name, equals('model.bin'));
      expect(artifact.role, equals(ArtifactRole.model));
      expect(artifact.format, equals('bin'));
    });

    test('fromJson parses complete data', () {
      final json = {
        'name': 'model.onnx',
        'role': 'model',
        'format': 'onnx',
        'path': 'model.onnx',
        'size': 2000,
        'sha256': 'def456',
      };

      final artifact = Artifact.fromJson(json);

      expect(artifact.name, equals('model.onnx'));
      expect(artifact.role, equals(ArtifactRole.model));
    });

    test('toJson produces correct output', () {
      const artifact = Artifact(
        name: 'model.gguf',
        role: ArtifactRole.model,
        format: 'gguf',
        path: 'model.gguf',
        size: 3000,
        sha256: 'ghi789',
      );

      final json = artifact.toJson();

      expect(json['name'], equals('model.gguf'));
      expect(json['role'], equals('model'));
    });
  });

  group('ArtifactRole', () {
    test('has all expected roles', () {
      expect(ArtifactRole.values, contains(ArtifactRole.model));
      expect(ArtifactRole.values, contains(ArtifactRole.tokenizer));
      expect(ArtifactRole.values, contains(ArtifactRole.config));
    });
  });
}
