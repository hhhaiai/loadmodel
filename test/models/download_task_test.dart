import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/models/download_task.dart';

void main() {
  group('DownloadProgress', () {
    test('progress calculates correctly when total > 0', () {
      final progress = DownloadProgress(
        modelId: 'test-model',
        received: 50,
        total: 100,
      );
      expect(progress.progress, equals(0.5));
    });

    test('progress returns 0 when total is 0', () {
      final progress = DownloadProgress(
        modelId: 'test-model',
        received: 50,
        total: 0,
      );
      expect(progress.progress, equals(0.0));
    });

    test('percent calculates correctly', () {
      final progress = DownloadProgress(
        modelId: 'test-model',
        received: 75,
        total: 100,
      );
      expect(progress.percent, equals(75));
    });

    test('formattedProgress returns percentage string', () {
      final progress = DownloadProgress(
        modelId: 'test-model',
        received: 50,
        total: 100,
      );
      expect(progress.formattedProgress, equals('50%'));
    });

    test('formattedReceived formats bytes correctly', () {
      expect(
        DownloadProgress(modelId: 'test', received: 1500, total: 2000).formattedReceived,
        contains('KB'),
      );
    });

    test('formattedTotal formats bytes correctly', () {
      expect(
        DownloadProgress(modelId: 'test', received: 500, total: 1500).formattedTotal,
        contains('KB'),
      );
    });

    test('formattedSpeed includes per second suffix', () {
      final progress = DownloadProgress(
        modelId: 'test',
        received: 500,
        total: 1000,
        speed: 1024,
      );
      expect(progress.formattedSpeed, equals('1.0 KB/s'));
    });

    test('copyWith creates new instance with updated values', () {
      final original = DownloadProgress(
        modelId: 'test',
        received: 50,
        total: 100,
        speed: 1000,
      );

      final updated = original.copyWith(received: 75);

      expect(updated.modelId, equals('test'));
      expect(updated.received, equals(75));
      expect(updated.total, equals(100));
      expect(updated.speed, equals(1000));
    });

    test('copyWith preserves original values when not specified', () {
      final original = DownloadProgress(
        modelId: 'test',
        received: 50,
        total: 100,
        speed: 1000,
      );

      final updated = original.copyWith();

      expect(updated.modelId, equals(original.modelId));
      expect(updated.received, equals(original.received));
      expect(updated.total, equals(original.total));
      expect(updated.speed, equals(original.speed));
    });
  });

  group('InstallPhase', () {
    test('all phases are defined', () {
      expect(InstallPhase.values, containsAll([
        InstallPhase.idle,
        InstallPhase.downloading,
        InstallPhase.verifying,
        InstallPhase.extracting,
        InstallPhase.ready,
        InstallPhase.failed,
      ]));
    });

    test('phase has correct names', () {
      expect(InstallPhase.idle.name, equals('idle'));
      expect(InstallPhase.downloading.name, equals('downloading'));
      expect(InstallPhase.verifying.name, equals('verifying'));
      expect(InstallPhase.extracting.name, equals('extracting'));
      expect(InstallPhase.ready.name, equals('ready'));
      expect(InstallPhase.failed.name, equals('failed'));
    });
  });
}
