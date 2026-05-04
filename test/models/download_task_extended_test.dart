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
  });
}
