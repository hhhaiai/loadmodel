import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/models/model_info.dart';
import 'package:model_loader/models/model_type.dart';

void main() {
  group('PlatformRequirements', () {
    test('creates with required parameters', () {
      final req = PlatformRequirements(minMemoryMB: 2048);
      expect(req.minMemoryMB, equals(2048));
      expect(req.supportsGpu, isFalse);
      expect(req.supportedPlatforms, containsAll(['ios', 'android', 'macos']));
    });

    test('creates with all parameters', () {
      final req = PlatformRequirements(
        minMemoryMB: 4096,
        supportsGpu: true,
        supportedPlatforms: ['ios', 'android'],
      );
      expect(req.minMemoryMB, equals(4096));
      expect(req.supportsGpu, isTrue);
      expect(req.supportedPlatforms, equals(['ios', 'android']));
    });

    test('fromJson parses complete data', () {
      final json = {
        'minMemory': 2048,
        'supportsGpu': true,
        'platforms': ['ios', 'android'],
      };
      final req = PlatformRequirements.fromJson(json);
      expect(req.minMemoryMB, equals(2048));
      expect(req.supportsGpu, isTrue);
      expect(req.supportedPlatforms, equals(['ios', 'android']));
    });

    test('fromJson handles missing values with defaults', () {
      final json = <String, dynamic>{};
      final req = PlatformRequirements.fromJson(json);
      expect(req.minMemoryMB, equals(0));
      expect(req.supportsGpu, isFalse);
    });

    test('toJson produces correct output', () {
      final req = PlatformRequirements(
        minMemoryMB: 2048,
        supportsGpu: true,
        supportedPlatforms: ['ios', 'android'],
      );
      final json = req.toJson();
      expect(json['minMemoryMB'], equals(2048));
      expect(json['supportsGpu'], isTrue);
      expect(json['platforms'], equals(['ios', 'android']));
    });
  });

  group('ModelInfo', () {
    test('creates with required parameters', () {
      final info = ModelInfo(
        id: 'test-model',
        name: 'Test Model',
        type: ModelType.llm,
        format: 'gguf',
        size: 1024 * 1024 * 100, // 100 MB
      );
      expect(info.id, equals('test-model'));
      expect(info.name, equals('Test Model'));
      expect(info.type, equals(ModelType.llm));
      expect(info.format, equals('gguf'));
      expect(info.version, equals('1.0.0')); // default
    });

    test('creates with all optional parameters', () {
      final info = ModelInfo(
        id: 'test-model',
        name: 'Test Model',
        type: ModelType.embedding,
        format: 'onnx',
        size: 1024,
        downloadUrl: 'https://example.com/model.onnx',
        sha256: 'abc123',
        version: '2.0.0',
        description: 'A test model',
        recommendedQuantizations: ['q4', 'q8'],
        platformReq: PlatformRequirements(minMemoryMB: 512),
      );
      expect(info.downloadUrl, equals('https://example.com/model.onnx'));
      expect(info.sha256, equals('abc123'));
      expect(info.version, equals('2.0.0'));
      expect(info.description, equals('A test model'));
      expect(info.recommendedQuantizations, equals(['q4', 'q8']));
      expect(info.platformReq?.minMemoryMB, equals(512));
    });

    test('formattedSize formats bytes correctly', () {
      expect(
        ModelInfo(id: 't', name: 't', type: ModelType.llm, format: 'gguf', size: 500).formattedSize,
        equals('500 B'),
      );
      expect(
        ModelInfo(id: 't', name: 't', type: ModelType.llm, format: 'gguf', size: 1024).formattedSize,
        equals('1.0 KB'),
      );
      expect(
        ModelInfo(id: 't', name: 't', type: ModelType.llm, format: 'gguf', size: 1024 * 1024).formattedSize,
        equals('1.0 MB'),
      );
      expect(
        ModelInfo(id: 't', name: 't', type: ModelType.llm, format: 'gguf', size: 1024 * 1024 * 1024).formattedSize,
        equals('1.0 GB'),
      );
    });

    test('fromJson parses complete data', () {
      final json = {
        'id': 'test-model',
        'name': 'Test Model',
        'type': 'embedding',
        'format': 'onnx',
        'size': 1024000,
        'version': '1.5.0',
        'downloadUrl': 'https://example.com/model.onnx',
        'sha256': 'def456',
        'description': 'Test embedding model',
        'recommendedQuantizations': ['q4', 'q8'],
        'minMemory': 512,
      };
      final info = ModelInfo.fromJson(json);
      expect(info.id, equals('test-model'));
      expect(info.type, equals(ModelType.embedding));
      expect(info.version, equals('1.5.0'));
      expect(info.platformReq?.minMemoryMB, equals(512));
    });

    test('fromJson handles missing values with defaults', () {
      final json = <String, dynamic>{};
      final info = ModelInfo.fromJson(json);
      expect(info.id, equals(''));
      expect(info.name, equals(''));
      expect(info.type, equals(ModelType.custom));
      expect(info.version, equals('1.0.0'));
      expect(info.size, equals(0));
    });

    test('toJson produces correct output', () {
      final info = ModelInfo(
        id: 'test-model',
        name: 'Test Model',
        type: ModelType.llm,
        format: 'gguf',
        size: 1024,
        version: '1.0.0',
      );
      final json = info.toJson();
      expect(json['id'], equals('test-model'));
      expect(json['type'], equals('llm'));
      expect(json['version'], equals('1.0.0'));
    });
  });
}
