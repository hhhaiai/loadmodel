import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/models/model_loader_exception.dart';

void main() {
  group('ModelLoaderErrorCode', () {
    test('all error codes have non-empty code strings', () {
      for (final code in ModelLoaderErrorCode.values) {
        expect(code.code, isNotEmpty);
        expect(code.code, isA<String>());
      }
    });

    test('all error codes have default messages', () {
      for (final code in ModelLoaderErrorCode.values) {
        expect(code.defaultMessage, isNotEmpty);
      }
    });

    test('non-retriable codes: MODEL_NOT_FOUND', () {
      expect(ModelLoaderErrorCode.MODEL_NOT_FOUND.isRetriable, isFalse);
    });

    test('non-retriable codes: UNSUPPORTED_PLATFORM', () {
      expect(ModelLoaderErrorCode.UNSUPPORTED_PLATFORM.isRetriable, isFalse);
    });

    test('non-retriable codes: INVALID_MODEL_FORMAT', () {
      expect(ModelLoaderErrorCode.INVALID_MODEL_FORMAT.isRetriable, isFalse);
    });

    test('non-retriable codes: CONFIG_ERROR', () {
      expect(ModelLoaderErrorCode.CONFIG_ERROR.isRetriable, isFalse);
    });

    test('retriable codes include MODEL_VERIFY_FAILED', () {
      expect(ModelLoaderErrorCode.MODEL_VERIFY_FAILED.isRetriable, isTrue);
    });

    test('retriable codes include TASK_TIMEOUT', () {
      expect(ModelLoaderErrorCode.TASK_TIMEOUT.isRetriable, isTrue);
    });

    test('retriable codes include TASK_CANCELLED', () {
      expect(ModelLoaderErrorCode.TASK_CANCELLED.isRetriable, isTrue);
    });

    test('retriable codes include DOWNLOAD_FAILED', () {
      expect(ModelLoaderErrorCode.DOWNLOAD_FAILED.isRetriable, isTrue);
    });
  });

  group('ModelLoaderErrorDetails', () {
    test('toJson includes backend when set', () {
      const details = ModelLoaderErrorDetails(backend: 'onnxruntime');
      expect(details.toJson()['backend'], 'onnxruntime');
    });

    test('toJson includes artifact when set', () {
      const details = ModelLoaderErrorDetails(artifact: 'model.onnx');
      expect(details.toJson()['artifact'], 'model.onnx');
    });

    test('toJson includes sha256 fields', () {
      const details = ModelLoaderErrorDetails(
        expectedSha256: 'abc123',
        actualSha256: 'def456',
      );
      final json = details.toJson();
      expect(json['expectedSha256'], 'abc123');
      expect(json['actualSha256'], 'def456');
    });

    test('toJson includes memory fields', () {
      const details = ModelLoaderErrorDetails(
        requiredMemoryMB: 1024,
        availableMemoryMB: 512,
      );
      final json = details.toJson();
      expect(json['requiredMemoryMB'], 1024);
      expect(json['availableMemoryMB'], 512);
    });

    test('toJson includes modelId when set', () {
      const details = ModelLoaderErrorDetails(modelId: 'tinyllama');
      expect(details.toJson()['modelId'], 'tinyllama');
    });

    test('toJson includes extra fields as flattened entries', () {
      const details = ModelLoaderErrorDetails(
        extra: {'key': 'value', 'count': 42},
      );
      final json = details.toJson();
      // extra entries are flattened into the parent map
      expect(json['key'], 'value');
      expect(json['count'], 42);
    });

    test('toJson omits null fields', () {
      const details = ModelLoaderErrorDetails();
      final json = details.toJson();
      expect(json.containsKey('backend'), isFalse);
      expect(json.containsKey('artifact'), isFalse);
    });

    test('fromJson restores all fields', () {
      final json = {
        'backend': 'llama.cpp',
        'artifact': 'model.gguf',
        'expectedSha256': 'hash1',
        'actualSha256': 'hash2',
        'requiredMemoryMB': 2048,
        'availableMemoryMB': 1024,
        'modelId': 'qwen',
        'extra': {'hint': 'oom'},
      };
      final details = ModelLoaderErrorDetails.fromJson(json);
      expect(details.backend, 'llama.cpp');
      expect(details.artifact, 'model.gguf');
      expect(details.expectedSha256, 'hash1');
      expect(details.actualSha256, 'hash2');
      expect(details.requiredMemoryMB, 2048);
      expect(details.availableMemoryMB, 1024);
      expect(details.modelId, 'qwen');
      expect(details.extra, {'hint': 'oom'});
    });

    test('fromJson handles missing optional fields', () {
      final details = ModelLoaderErrorDetails.fromJson({});
      expect(details.backend, isNull);
      expect(details.artifact, isNull);
      expect(details.modelId, isNull);
      expect(details.extra, isNull);
    });
  });

  group('ModelLoaderException', () {
    test('displayMessage uses message when provided', () {
      const ex = ModelLoaderException(
        code: ModelLoaderErrorCode.MODEL_NOT_FOUND,
        message: 'Custom message',
      );
      expect(ex.displayMessage, 'Custom message');
    });

    test('displayMessage falls back to code.defaultMessage', () {
      const ex = ModelLoaderException(code: ModelLoaderErrorCode.MODEL_NOT_FOUND);
      expect(ex.displayMessage, 'Model not found');
    });

    test('toJson includes code, message, retriable, details, suggestion', () {
      const ex = ModelLoaderException(
        code: ModelLoaderErrorCode.MODEL_LOAD_FAILED,
        message: 'Load failed',
        retriable: true,
        details: ModelLoaderErrorDetails(backend: 'onnx'),
        suggestion: 'Try again',
      );
      final json = ex.toJson();
      expect(json['code'], 'MODEL_LOAD_FAILED');
      expect(json['message'], 'Load failed');
      expect(json['retriable'], true);
      expect(json['details']['backend'], 'onnx');
      expect(json['suggestion'], 'Try again');
    });

    test('toJson includes suggestion when non-null', () {
      const ex = ModelLoaderException(
        code: ModelLoaderErrorCode.UNKNOWN,
        message: 'Unknown error',
        suggestion: 'Try restarting',
      );
      final json = ex.toJson();
      expect(json['suggestion'], 'Try restarting');
    });

    test('toJson includes null suggestion as explicit null', () {
      const ex = ModelLoaderException(
        code: ModelLoaderErrorCode.UNKNOWN,
        message: 'Unknown error',
      );
      final json = ex.toJson();
      // toJson() uses map literal so null fields are still present as null
      expect(json.containsKey('suggestion'), true);
      expect(json['suggestion'], isNull);
    });

    test('fromJson restores exception correctly', () {
      final json = {
        'code': 'INFERENCE_FAILED',
        'message': 'Inference error',
        'retriable': true,
        'details': {'backend': 'ort'},
        'suggestion': 'Check input',
      };
      final ex = ModelLoaderException.fromJson(json);
      expect(ex.code, ModelLoaderErrorCode.INFERENCE_FAILED);
      expect(ex.message, 'Inference error');
      expect(ex.retriable, true);
      expect(ex.details?.backend, 'ort');
      expect(ex.suggestion, 'Check input');
    });

    test('fromJson defaults retriable to false when missing', () {
      final ex = ModelLoaderException.fromJson({
        'code': 'MODEL_NOT_FOUND',
      });
      expect(ex.retriable, false);
    });

    test('fromJson falls back to UNKNOWN for unknown code', () {
      final ex = ModelLoaderException.fromJson({'code': 'NOT_A_REAL_CODE'});
      expect(ex.code, ModelLoaderErrorCode.UNKNOWN);
    });

    test('toString returns formatted string', () {
      const ex = ModelLoaderException(
        code: ModelLoaderErrorCode.MODEL_NOT_FOUND,
        message: 'Model missing',
      );
      expect(ex.toString(), 'ModelLoaderException: MODEL_NOT_FOUND - Model missing');
    });

    group('factory constructors', () {
      test('modelNotFound creates correct exception', () {
        final ex = ModelLoaderException.modelNotFound('tinyllama');
        expect(ex.code, ModelLoaderErrorCode.MODEL_NOT_FOUND);
        expect(ex.message, 'Model not found: tinyllama');
        expect(ex.retriable, false);
        expect(ex.details?.modelId, 'tinyllama');
        expect(ex.suggestion, contains('download'));
      });

      test('modelVerifyFailed creates correct exception', () {
        final ex = ModelLoaderException.modelVerifyFailed(
          artifact: 'model.onnx',
          expectedSha256: 'hash123',
          actualSha256: 'hash456',
        );
        expect(ex.code, ModelLoaderErrorCode.MODEL_VERIFY_FAILED);
        expect(ex.message, contains('model.onnx'));
        expect(ex.retriable, true);
        expect(ex.details?.artifact, 'model.onnx');
        expect(ex.details?.expectedSha256, 'hash123');
        expect(ex.details?.actualSha256, 'hash456');
        expect(ex.suggestion, contains('Re-download'));
      });

      test('runtimeNotAvailable creates correct exception', () {
        final ex = ModelLoaderException.runtimeNotAvailable(
          backend: 'onnxruntime',
          reason: 'native library not found',
        );
        expect(ex.code, ModelLoaderErrorCode.RUNTIME_NOT_AVAILABLE);
        expect(ex.message, contains('onnxruntime'));
        expect(ex.message, contains('native library not found'));
        expect(ex.retriable, true);
        expect(ex.details?.backend, 'onnxruntime');
        expect(ex.suggestion, contains('alternative'));
      });

      test('runtimeNotAvailable handles null reason', () {
        final ex = ModelLoaderException.runtimeNotAvailable(backend: 'ort');
        expect(ex.message, contains('ort'));
        expect(ex.message.contains('null'), isFalse);
      });

      test('insufficientMemory creates correct exception', () {
        final ex = ModelLoaderException.insufficientMemory(
          requiredMB: 4096,
          availableMB: 2048,
          modelId: 'qwen-7b',
        );
        expect(ex.code, ModelLoaderErrorCode.INSUFFICIENT_MEMORY);
        expect(ex.message, contains('4096'));
        expect(ex.message, contains('2048'));
        expect(ex.retriable, true);
        expect(ex.details?.requiredMemoryMB, 4096);
        expect(ex.details?.availableMemoryMB, 2048);
        expect(ex.details?.modelId, 'qwen-7b');
        expect(ex.suggestion, contains('smaller model'));
      });

      test('downloadFailed creates correct exception', () {
        final ex = ModelLoaderException.downloadFailed(
          url: 'https://example.com/model.gguf',
          error: Exception('connection reset'),
        );
        expect(ex.code, ModelLoaderErrorCode.DOWNLOAD_FAILED);
        expect(ex.message, contains('https://example.com/model.gguf'));
        expect(ex.retriable, true);
        expect(ex.originalError, isA<Exception>());
        expect(ex.suggestion, contains('network'));
      });
    });
  });
}
