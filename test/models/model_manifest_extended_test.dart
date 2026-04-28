import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/models/model_manifest.dart';

void main() {
  group('Artifact', () {
    test('creates with required parameters', () {
      const artifact = Artifact(
        name: 'model.gguf',
        role: ArtifactRole.model,
        format: 'gguf',
        path: 'model.gguf',
        size: 1000000,
        sha256: 'abc123',
      );
      expect(artifact.name, 'model.gguf');
      expect(artifact.role, ArtifactRole.model);
      expect(artifact.format, 'gguf');
      expect(artifact.path, 'model.gguf');
      expect(artifact.size, 1000000);
      expect(artifact.sha256, 'abc123');
    });

    test('fromJson parses complete data', () {
      final json = {
        'name': 'model.bin',
        'role': 'model',
        'format': 'bin',
        'path': 'model.bin',
        'size': 2000000,
        'sha256': 'ghi789',
      };
      final artifact = Artifact.fromJson(json);
      expect(artifact.name, 'model.bin');
      expect(artifact.role, ArtifactRole.model);
      expect(artifact.size, 2000000);
    });

    test('fromJson handles missing values with defaults', () {
      final json = <String, dynamic>{};
      final artifact = Artifact.fromJson(json);
      expect(artifact.name, '');
      expect(artifact.role, ArtifactRole.model);
    });

    test('toJson produces correct output', () {
      const artifact = Artifact(
        name: 'model.onnx',
        role: ArtifactRole.model,
        format: 'onnx',
        path: 'model.onnx',
        size: 500000,
        sha256: 'jkl012',
      );
      final json = artifact.toJson();
      expect(json['name'], 'model.onnx');
      expect(json['role'], 'model');
    });
  });

  group('ArtifactRole', () {
    test('has all expected values', () {
      expect(ArtifactRole.values, contains(ArtifactRole.model));
      expect(ArtifactRole.values, contains(ArtifactRole.tokenizer));
      expect(ArtifactRole.values, contains(ArtifactRole.config));
      expect(ArtifactRole.values, contains(ArtifactRole.vocab));
      expect(ArtifactRole.values, contains(ArtifactRole.adapter));
    });
  });

  group('MinSdkVersion', () {
    test('creates with required parameters', () {
      const minSdk = MinSdkVersion(android: 24);
      expect(minSdk.android, 24);
      expect(minSdk.ios, isNull);
    });

    test('creates with all parameters', () {
      const minSdk = MinSdkVersion(android: 24, ios: '14.0');
      expect(minSdk.android, 24);
      expect(minSdk.ios, '14.0');
    });

    test('fromJson parses complete data', () {
      final json = {'android': 26, 'ios': '15.0'};
      final minSdk = MinSdkVersion.fromJson(json);
      expect(minSdk.android, 26);
      expect(minSdk.ios, '15.0');
    });

    test('toJson produces correct output', () {
      const minSdk = MinSdkVersion(android: 24, ios: '14.0');
      final json = minSdk.toJson();
      expect(json['android'], 24);
      expect(json['ios'], '14.0');
    });
  });

  group('MinBackendVersion', () {
    test('creates with required parameters', () {
      const version = MinBackendVersion(llamaCpp: '0.1.0');
      expect(version.llamaCpp, '0.1.0');
      expect(version.onnxruntime, isNull);
    });

    test('creates with all parameters', () {
      const version = MinBackendVersion(
        llamaCpp: '0.1.0',
        onnxruntime: '1.12.0',
        tflite: '2.10.0',
      );
      expect(version.llamaCpp, '0.1.0');
      expect(version.onnxruntime, '1.12.0');
      expect(version.tflite, '2.10.0');
    });

    test('fromJson parses complete data', () {
      final json = {'llama.cpp': '0.2.0', 'onnxruntime': '1.14.0'};
      final version = MinBackendVersion.fromJson(json);
      expect(version.llamaCpp, '0.2.0');
      expect(version.onnxruntime, '1.14.0');
    });

    test('toJson produces correct output', () {
      const version = MinBackendVersion(llamaCpp: '0.1.0');
      final json = version.toJson();
      expect(json['llama.cpp'], '0.1.0');
    });
  });

  group('DefaultGenerationConfig', () {
    test('creates with default values', () {
      const config = DefaultGenerationConfig();
      expect(config.maxTokens, isNull);
      expect(config.temperature, isNull);
      expect(config.topP, isNull);
      expect(config.topK, isNull);
      expect(config.repeatPenalty, isNull);
    });

    test('creates with custom values', () {
      const config = DefaultGenerationConfig(
        maxTokens: 4096,
        temperature: 0.5,
        topP: 0.95,
        topK: 50,
        repeatPenalty: 1.2,
      );
      expect(config.maxTokens, 4096);
      expect(config.temperature, 0.5);
      expect(config.topP, 0.95);
      expect(config.topK, 50);
      expect(config.repeatPenalty, 1.2);
    });

    test('toJson produces correct output', () {
      const config = DefaultGenerationConfig(maxTokens: 1024);
      final json = config.toJson();
      expect(json['maxTokens'], 1024);
      expect(json['temperature'], isNull);
    });

    test('fromJson parses complete data', () {
      final json = {
        'maxTokens': 4096,
        'temperature': 0.8,
        'topP': 0.85,
        'topK': 30,
        'repeatPenalty': 1.15,
      };
      final config = DefaultGenerationConfig.fromJson(json);
      expect(config.maxTokens, 4096);
      expect(config.temperature, 0.8);
    });
  });

  group('SpecialTokens', () {
    test('creates with default values', () {
      const tokens = SpecialTokens();
      expect(tokens.bos, isNull);
      expect(tokens.eos, isNull);
      expect(tokens.unk, isNull);
      expect(tokens.pad, isNull);
    });

    test('creates with all parameters', () {
      const tokens = SpecialTokens(
        bos: '<s>',
        eos: '</s>',
        unk: '<unk>',
        pad: '<pad>',
        extra: {'special': 'value'},
      );
      expect(tokens.bos, '<s>');
      expect(tokens.eos, '</s>');
      expect(tokens.unk, '<unk>');
      expect(tokens.pad, '<pad>');
      expect(tokens.extra, isNotNull);
    });

    test('toJson produces correct output', () {
      const tokens = SpecialTokens(bos: '<s>', eos: '</s>');
      final json = tokens.toJson();
      expect(json['bos'], '<s>');
      expect(json['eos'], '</s>');
    });

    test('fromJson parses complete data', () {
      final json = {
        'bos': '<s>',
        'eos': '</s>',
        'unk': '<unk>',
        'pad': '<pad>',
      };
      final tokens = SpecialTokens.fromJson(json);
      expect(tokens.bos, '<s>');
      expect(tokens.eos, '</s>');
      expect(tokens.unk, '<unk>');
      expect(tokens.pad, '<pad>');
    });

    test('fromJson handles missing values', () {
      final json = <String, dynamic>{};
      final tokens = SpecialTokens.fromJson(json);
      expect(tokens.bos, isNull);
      expect(tokens.eos, isNull);
    });
  });

  group('ModelManifest', () {
    test('creates with required parameters', () {
      const manifest = ModelManifest(
        manifestSchemaVersion: '1.0.0',
        manifestVersion: '1.0',
        generatedAt: '2024-01-01T00:00:00Z',
        models: [],
      );
      expect(manifest.manifestSchemaVersion, '1.0.0');
      expect(manifest.models, isEmpty);
    });

    test('fromJson parses complete data', () {
      final json = {
        'manifestSchemaVersion': '1.0.0',
        'manifestVersion': '1.0',
        'generatedAt': '2024-01-01T00:00:00Z',
        'models': [],
      };
      final manifest = ModelManifest.fromJson(json);
      expect(manifest.manifestSchemaVersion, '1.0.0');
    });

    test('toJson produces correct output', () {
      const manifest = ModelManifest(
        manifestSchemaVersion: '1.0.0',
        manifestVersion: '1.0',
        generatedAt: '2024-01-01T00:00:00Z',
        models: [],
      );
      final json = manifest.toJson();
      expect(json['manifestSchemaVersion'], '1.0.0');
      expect(json['models'], isA<List>());
    });
  });
}
