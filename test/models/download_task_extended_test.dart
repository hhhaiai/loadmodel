import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/models/download_task.dart';

void main() {
  group('DownloadProgress', () {
    test('creates with required parameters', () {
      const progress = DownloadProgress(
        modelId: 'test-model',
        received: 500,
        total: 1000,
      );
      expect(progress.modelId, 'test-model');
      expect(progress.received, 500);
      expect(progress.total, 1000);
    });

    test('creates with all parameters', () {
      const progress = DownloadProgress(
        modelId: 'test-model',
        received: 500,
        total: 1000,
        speed: 1024,
      );
      expect(progress.speed, 1024);
    });

    test('progress calculates correctly', () {
      const progress = DownloadProgress(
        modelId: 'test-model',
        received: 500,
        total: 1000,
      );
      expect(progress.progress, 0.5);
    });

    test('progress returns 0 when total is 0', () {
      const progress = DownloadProgress(
        modelId: 'test-model',
        received: 0,
        total: 0,
      );
      expect(progress.progress, 0.0);
    });

    test('percent calculates correctly', () {
      const progress = DownloadProgress(
        modelId: 'test-model',
        received: 500,
        total: 1000,
      );
      expect(progress.percent, 50);
    });

    test('formattedProgress returns correct string', () {
      const progress = DownloadProgress(
        modelId: 'test-model',
        received: 500,
        total: 1000,
      );
      expect(progress.formattedProgress, '50%');
    });

    test('formattedReceived formats bytes correctly', () {
      const progress = DownloadProgress(
        modelId: 'test-model',
        received: 1500,
        total: 1000,
      );
      expect(progress.formattedReceived, '1.5 KB');
    });

    test('formattedTotal formats bytes correctly', () {
      const progress = DownloadProgress(
        modelId: 'test-model',
        received: 500,
        total: 1500000,
      );
      expect(progress.formattedTotal, '1.4 MB');
    });

    test('formattedSpeed formats bytes correctly', () {
      const progress = DownloadProgress(
        modelId: 'test-model',
        received: 500,
        total: 1000,
        speed: 1024,
      );
      expect(progress.formattedSpeed, '1.0 KB/s');
    });

    group('copyWith', () {
      test('copyWith with all parameters', () {
        const original = DownloadProgress(
          modelId: 'original-model',
          received: 100,
          total: 200,
          speed: 500,
        );
        final updated = original.copyWith(
          modelId: 'new-model',
          received: 150,
          total: 300,
          speed: 750,
        );
        expect(updated.modelId, 'new-model');
        expect(updated.received, 150);
        expect(updated.total, 300);
        expect(updated.speed, 750);
      });

      test('copyWith with single parameter change', () {
        const original = DownloadProgress(
          modelId: 'test-model',
          received: 100,
          total: 200,
          speed: 500,
        );
        final updated = original.copyWith(received: 180);
        expect(updated.modelId, 'test-model');
        expect(updated.received, 180);
        expect(updated.total, 200);
        expect(updated.speed, 500);
      });

      test('copyWith preserves values when nulls passed', () {
        const original = DownloadProgress(
          modelId: 'test-model',
          received: 100,
          total: 200,
          speed: 500,
        );
        final updated = original.copyWith();
        expect(updated.modelId, 'test-model');
        expect(updated.received, 100);
        expect(updated.total, 200);
        expect(updated.speed, 500);
      });

      test('copyWith with total=0 and non-zero received preserves progress=0', () {
        const original = DownloadProgress(
          modelId: 'test-model',
          received: 0,
          total: 0,
        );
        final updated = original.copyWith(received: 100);
        expect(updated.total, 0);
        expect(updated.received, 100);
        expect(updated.progress, 0.0);
      });
    });
  });

  group('InstallPhase', () {
    test('has all expected values', () {
      expect(InstallPhase.values, contains(InstallPhase.idle));
      expect(InstallPhase.values, contains(InstallPhase.downloading));
      expect(InstallPhase.values, contains(InstallPhase.extracting));
      expect(InstallPhase.values, contains(InstallPhase.verifying));
      expect(InstallPhase.values, contains(InstallPhase.ready));
      expect(InstallPhase.values, contains(InstallPhase.failed));
      expect(InstallPhase.values, contains(InstallPhase.cancelled));
    });

    test('isTerminal returns true for ready/failed/cancelled', () {
      expect(InstallPhase.ready.isTerminal, isTrue);
      expect(InstallPhase.failed.isTerminal, isTrue);
      expect(InstallPhase.cancelled.isTerminal, isTrue);
    });

    test('isTerminal returns false for non-terminal phases', () {
      expect(InstallPhase.idle.isTerminal, isFalse);
      expect(InstallPhase.downloading.isTerminal, isFalse);
      expect(InstallPhase.verifying.isTerminal, isFalse);
      expect(InstallPhase.extracting.isTerminal, isFalse);
    });

    test('phase names are correct', () {
      expect(InstallPhase.idle.name, equals('idle'));
      expect(InstallPhase.downloading.name, equals('downloading'));
      expect(InstallPhase.verifying.name, equals('verifying'));
      expect(InstallPhase.extracting.name, equals('extracting'));
      expect(InstallPhase.ready.name, equals('ready'));
      expect(InstallPhase.failed.name, equals('failed'));
      expect(InstallPhase.cancelled.name, equals('cancelled'));
    });
  });

  group('InstallProgress', () {
    test('creates with required parameters', () {
      const progress = InstallProgress(
        modelId: 'test-model',
        version: '1.0.0',
        phase: InstallPhase.downloading,
        requestId: 'req-1',
      );
      expect(progress.modelId, 'test-model');
      expect(progress.version, '1.0.0');
      expect(progress.phase, InstallPhase.downloading);
    });

    test('creates with all optional parameters', () {
      const progress = InstallProgress(
        modelId: 'test-model',
        version: '1.0.0',
        phase: InstallPhase.verifying,
        requestId: 'req-1',
        progress: 0.5,
        receivedBytes: 500,
        totalBytes: 1000,
      );
      expect(progress.progress, 0.5);
      expect(progress.receivedBytes, 500);
      expect(progress.totalBytes, 1000);
    });

    test('fromJson deserializes correctly', () {
      final progress = InstallProgress.fromJson({
        'modelId': 'model-1',
        'version': '1.0.0',
        'phase': 'downloading',
        'receivedBytes': 500,
        'totalBytes': 1000,
        'progress': 0.5,
        'requestId': 'req-1',
        'error': null,
      });
      expect(progress.modelId, equals('model-1'));
      expect(progress.version, equals('1.0.0'));
      expect(progress.phase, equals(InstallPhase.downloading));
      expect(progress.receivedBytes, equals(500));
      expect(progress.totalBytes, equals(1000));
      expect(progress.progress, equals(0.5));
      expect(progress.requestId, equals('req-1'));
      expect(progress.error, isNull);
    });

    test('fromJson handles missing fields with defaults', () {
      final progress = InstallProgress.fromJson({});
      expect(progress.modelId, equals(''));
      expect(progress.version, equals('1.0.0'));
      expect(progress.phase, equals(InstallPhase.idle));
      expect(progress.receivedBytes, equals(0));
      expect(progress.totalBytes, equals(0));
      expect(progress.progress, equals(0.0));
      expect(progress.requestId, equals(''));
      expect(progress.error, isNull);
    });

    test('fromJson handles unknown phase', () {
      final progress = InstallProgress.fromJson({'phase': 'unknown'});
      expect(progress.phase, equals(InstallPhase.idle));
    });

    test('toJson serializes correctly', () {
      const progress = InstallProgress(
        modelId: 'model-1',
        version: '1.0.0',
        phase: InstallPhase.downloading,
        receivedBytes: 500,
        totalBytes: 1000,
        progress: 0.5,
        requestId: 'req-1',
      );
      final json = progress.toJson();
      expect(json['modelId'], equals('model-1'));
      expect(json['version'], equals('1.0.0'));
      expect(json['phase'], equals('downloading'));
      expect(json['receivedBytes'], equals(500));
      expect(json['totalBytes'], equals(1000));
      expect(json['progress'], equals(0.5));
      expect(json['requestId'], equals('req-1'));
      expect(json['error'], isNull);
    });

    test('toJson includes error when present', () {
      const progress = InstallProgress(
        modelId: 'model-1',
        version: '1.0.0',
        phase: InstallPhase.failed,
        requestId: 'req-1',
        error: {'message': 'download failed'},
      );
      final json = progress.toJson();
      expect(json['error'], equals({'message': 'download failed'}));
    });

    group('copyWith', () {
      test('copyWith with all parameters', () {
        const original = InstallProgress(
          modelId: 'original-model',
          version: '1.0.0',
          phase: InstallPhase.downloading,
          requestId: 'req-1',
          progress: 0.5,
          receivedBytes: 500,
          totalBytes: 1000,
        );
        final updated = original.copyWith(
          modelId: 'new-model',
          version: '2.0.0',
          phase: InstallPhase.ready,
          requestId: 'req-2',
          progress: 1.0,
          receivedBytes: 1000,
          totalBytes: 1000,
        );
        expect(updated.modelId, 'new-model');
        expect(updated.version, '2.0.0');
        expect(updated.phase, InstallPhase.ready);
        expect(updated.requestId, 'req-2');
        expect(updated.progress, 1.0);
        expect(updated.receivedBytes, 1000);
        expect(updated.totalBytes, 1000);
      });

      test('copyWith with single parameter change', () {
        const original = InstallProgress(
          modelId: 'test-model',
          version: '1.0.0',
          phase: InstallPhase.downloading,
          requestId: 'req-1',
          progress: 0.3,
        );
        final updated = original.copyWith(phase: InstallPhase.extracting);
        expect(updated.modelId, 'test-model');
        expect(updated.version, '1.0.0');
        expect(updated.phase, InstallPhase.extracting);
        expect(updated.requestId, 'req-1');
        expect(updated.progress, 0.3);
      });

      test('copyWith preserves values when not specified', () {
        const original = InstallProgress(
          modelId: 'test-model',
          version: '1.0.0',
          phase: InstallPhase.verifying,
          requestId: 'req-1',
          progress: 0.75,
          receivedBytes: 750,
          totalBytes: 1000,
        );
        final updated = original.copyWith();
        expect(updated.modelId, 'test-model');
        expect(updated.version, '1.0.0');
        expect(updated.phase, InstallPhase.verifying);
        expect(updated.requestId, 'req-1');
        expect(updated.progress, 0.75);
        expect(updated.receivedBytes, 750);
        expect(updated.totalBytes, 1000);
      });

      test('copyWith with error map', () {
        const original = InstallProgress(
          modelId: 'test-model',
          version: '1.0.0',
          phase: InstallPhase.downloading,
          requestId: 'req-1',
        );
        final updated = original.copyWith(
          phase: InstallPhase.failed,
          error: {'code': 'NETWORK_ERROR', 'message': 'Connection timed out'},
        );
        expect(updated.phase, InstallPhase.failed);
        expect(updated.error, isNotNull);
        expect(updated.error!['code'], 'NETWORK_ERROR');
      });
    });
  });

  group('DownloadStatus', () {
    test('has all expected values', () {
      expect(DownloadStatus.values, contains(DownloadStatus.pending));
      expect(DownloadStatus.values, contains(DownloadStatus.downloading));
      expect(DownloadStatus.values, contains(DownloadStatus.paused));
      expect(DownloadStatus.values, contains(DownloadStatus.completed));
      expect(DownloadStatus.values, contains(DownloadStatus.failed));
      expect(DownloadStatus.values, contains(DownloadStatus.cancelled));
    });

    test('displayName returns correct Chinese text', () {
      expect(DownloadStatus.pending.displayName, equals('等待中'));
      expect(DownloadStatus.downloading.displayName, equals('下载中'));
      expect(DownloadStatus.paused.displayName, equals('已暂停'));
      expect(DownloadStatus.completed.displayName, equals('已完成'));
      expect(DownloadStatus.failed.displayName, equals('下载失败'));
      expect(DownloadStatus.cancelled.displayName, equals('已取消'));
    });
  });

  group('DownloadTask', () {
    test('creates with required parameters', () {
      final task = DownloadTask(
        id: 'task-1',
        modelId: 'test-model',
        modelName: 'Test Model',
        savePath: '/path/to/model.gguf',
      );
      expect(task.id, 'task-1');
      expect(task.modelId, 'test-model');
      expect(task.modelName, 'Test Model');
      expect(task.savePath, '/path/to/model.gguf');
      expect(task.status, DownloadStatus.pending);
    });

    test('creates with all optional parameters', () {
      final task = DownloadTask(
        id: 'task-1',
        modelId: 'test-model',
        modelName: 'Test Model',
        savePath: '/path/to/model.gguf',
        error: 'Some error',
      );
      expect(task.error, 'Some error');
    });

    test('status can be changed', () {
      final task = DownloadTask(
        id: 'task-1',
        modelId: 'test-model',
        modelName: 'Test Model',
        savePath: '/path/to/model.gguf',
      );
      task.status = DownloadStatus.downloading;
      expect(task.status, DownloadStatus.downloading);
    });

    test('cancel sets cancelled flag and status', () {
      final task = DownloadTask(
        id: 'task-1',
        modelId: 'model-1',
        modelName: 'Test Model',
        savePath: '/tmp/model',
      );
      task.cancel();
      expect(task.isCancelled, isTrue);
      expect(task.status, equals(DownloadStatus.cancelled));
    });

    test('pause changes status from downloading to paused', () {
      final task = DownloadTask(
        id: 'task-1',
        modelId: 'model-1',
        modelName: 'Test Model',
        savePath: '/tmp/model',
        status: DownloadStatus.downloading,
      );
      task.pause();
      expect(task.status, equals(DownloadStatus.paused));
    });

    test('pause does nothing if not downloading', () {
      final task = DownloadTask(
        id: 'task-1',
        modelId: 'model-1',
        modelName: 'Test Model',
        savePath: '/tmp/model',
        status: DownloadStatus.pending,
      );
      task.pause();
      expect(task.status, equals(DownloadStatus.pending));
    });

    test('resume changes status from paused to downloading', () {
      final task = DownloadTask(
        id: 'task-1',
        modelId: 'model-1',
        modelName: 'Test Model',
        savePath: '/tmp/model',
        status: DownloadStatus.paused,
      );
      task.resume();
      expect(task.status, equals(DownloadStatus.downloading));
    });

    test('resume does nothing if not paused', () {
      final task = DownloadTask(
        id: 'task-1',
        modelId: 'model-1',
        modelName: 'Test Model',
        savePath: '/tmp/model',
        status: DownloadStatus.pending,
      );
      task.resume();
      expect(task.status, equals(DownloadStatus.pending));
    });

    test('createdAt defaults to now if not specified', () {
      final before = DateTime.now();
      final task = DownloadTask(
        id: 'task-1',
        modelId: 'model-1',
        modelName: 'Test Model',
        savePath: '/tmp/model',
      );
      final after = DateTime.now();
      expect(task.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(task.createdAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('createdAt can be specified', () {
      final specified = DateTime(2025, 1, 1);
      final task = DownloadTask(
        id: 'task-1',
        modelId: 'model-1',
        modelName: 'Test Model',
        savePath: '/tmp/model',
        createdAt: specified,
      );
      expect(task.createdAt, equals(specified));
    });
  });
}
