import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/core/task_scheduler.dart';

void main() {
  setUpAll(() {
    // Reset singleton before all tests
    TaskScheduler.resetInstance();
  });

  tearDownAll(() {
    // Clean up after all tests
    TaskScheduler.resetInstance();
  });

  group('Task', () {
    test('creates with required parameters', () {
      final task = Task(
        id: 'test_task',
        type: TaskType.llm,
        execute: () async => 'result',
      );

      expect(task.id, equals('test_task'));
      expect(task.type, equals(TaskType.llm));
      expect(task.status, equals(TaskStatus.pending));
      expect(task.priority, equals(TaskPriority.normal));
      expect(task.cancellable, isTrue);
    });

    test('creates with all optional parameters', () {
      final task = Task(
        id: 'test_task',
        type: TaskType.llm,
        priority: TaskPriority.high,
        resourceType: ResourceType.gpuBound,
        execute: () async => 'result',
        timeout: const Duration(minutes: 5),
        cancellable: false,
        metadata: {'key': 'value'},
      );

      expect(task.priority, equals(TaskPriority.high));
      expect(task.resourceType, equals(ResourceType.gpuBound));
      expect(task.timeout, equals(const Duration(minutes: 5)));
      expect(task.cancellable, isFalse);
      expect(task.metadata, equals({'key': 'value'}));
    });

    test('cancel changes status when pending and cancellable', () {
      final task = Task(
        id: 'test_task',
        type: TaskType.llm,
        cancellable: true,
        execute: () async => 'result',
      );

      task.cancel();

      expect(task.status, equals(TaskStatus.cancelled));
    });

    test('cancel does not change status when not cancellable', () {
      final task = Task(
        id: 'test_task',
        type: TaskType.llm,
        cancellable: false,
        execute: () async => 'result',
      );

      task.cancel();

      expect(task.status, equals(TaskStatus.pending));
    });

    test('cancel does not change status when running', () {
      final task = Task(
        id: 'test_task',
        type: TaskType.llm,
        cancellable: true,
        status: TaskStatus.running,
        execute: () async => 'result',
      );

      task.cancel();

      expect(task.status, equals(TaskStatus.running));
    });

    test('isDone returns true for completed', () {
      final task = Task(
        id: 'test_task',
        type: TaskType.llm,
        status: TaskStatus.completed,
        execute: () async => 'result',
      );

      expect(task.isDone, isTrue);
    });

    test('isDone returns true for failed', () {
      final task = Task(
        id: 'test_task',
        type: TaskType.llm,
        status: TaskStatus.failed,
        execute: () async => 'result',
      );

      expect(task.isDone, isTrue);
    });

    test('isDone returns true for cancelled', () {
      final task = Task(
        id: 'test_task',
        type: TaskType.llm,
        status: TaskStatus.cancelled,
        execute: () async => 'result',
      );

      expect(task.isDone, isTrue);
    });

    test('isDone returns true for timeout', () {
      final task = Task(
        id: 'test_task',
        type: TaskType.llm,
        status: TaskStatus.timeout,
        execute: () async => 'result',
      );

      expect(task.isDone, isTrue);
    });

    test('isDone returns false for pending', () {
      final task = Task(
        id: 'test_task',
        type: TaskType.llm,
        status: TaskStatus.pending,
        execute: () async => 'result',
      );

      expect(task.isDone, isFalse);
    });

    test('setCancelCallback registers callback', () {
      var called = false;
      final task = Task(
        id: 'test_task',
        type: TaskType.llm,
        cancellable: true,
        execute: () async => 'result',
      );

      task.setCancelCallback(() {
        called = true;
      });

      task.cancel();

      expect(called, isTrue);
    });
  });

  group('TaskPriority', () {
    test('has correct values', () {
      expect(TaskPriority.low.value, equals(0));
      expect(TaskPriority.normal.value, equals(1));
      expect(TaskPriority.high.value, equals(2));
      expect(TaskPriority.critical.value, equals(3));
    });
  });

  group('TaskType', () {
    test('has all expected types', () {
      expect(TaskType.values, contains(TaskType.llm));
      expect(TaskType.values, contains(TaskType.ocr));
      expect(TaskType.values, contains(TaskType.stt));
      expect(TaskType.values, contains(TaskType.tts));
      expect(TaskType.values, contains(TaskType.embedding));
      expect(TaskType.values, contains(TaskType.download));
      expect(TaskType.values, contains(TaskType.verify));
      expect(TaskType.values, contains(TaskType.other));
    });
  });

  group('TaskStatus', () {
    test('has all expected statuses', () {
      expect(TaskStatus.values, contains(TaskStatus.pending));
      expect(TaskStatus.values, contains(TaskStatus.running));
      expect(TaskStatus.values, contains(TaskStatus.completed));
      expect(TaskStatus.values, contains(TaskStatus.failed));
      expect(TaskStatus.values, contains(TaskStatus.cancelled));
      expect(TaskStatus.values, contains(TaskStatus.timeout));
    });
  });

  group('QueueConfig', () {
    test('creates with default values', () {
      const config = QueueConfig();

      expect(config.maxConcurrent, equals(1));
      expect(config.rejectOnFull, isFalse);
    });

    test('creates with custom values', () {
      const config = QueueConfig(maxConcurrent: 5, rejectOnFull: true);

      expect(config.maxConcurrent, equals(5));
      expect(config.rejectOnFull, isTrue);
    });
  });

  group('DefaultQueueConfigs', () {
    test('provides configs for all task types', () {
      for (final type in TaskType.values) {
        final config = DefaultQueueConfigs.forType(type);
        expect(config, isNotNull);
        expect(config.maxConcurrent, greaterThan(0));
      }
    });

    test('llm has maxConcurrent 1', () {
      expect(DefaultQueueConfigs.llm.maxConcurrent, equals(1));
    });

    test('ocr has maxConcurrent 2', () {
      expect(DefaultQueueConfigs.ocr.maxConcurrent, equals(2));
    });

    test('download has maxConcurrent 3', () {
      expect(DefaultQueueConfigs.download.maxConcurrent, equals(3));
    });
  });

  group('SchedulerStats', () {
    test('creates with default values', () {
      const stats = SchedulerStats();

      expect(stats.totalSubmitted, equals(0));
      expect(stats.totalCompleted, equals(0));
      expect(stats.totalFailed, equals(0));
      expect(stats.totalCancelled, equals(0));
      expect(stats.totalTimeout, equals(0));
      expect(stats.pendingCount, equals(0));
      expect(stats.runningCount, equals(0));
    });

    test('creates with custom values', () {
      const stats = SchedulerStats(
        totalSubmitted: 10,
        totalCompleted: 8,
        totalFailed: 1,
        totalCancelled: 1,
        totalTimeout: 0,
        pendingCount: 2,
        runningCount: 1,
      );

      expect(stats.totalSubmitted, equals(10));
      expect(stats.totalCompleted, equals(8));
      expect(stats.totalFailed, equals(1));
    });
  });

  group('TaskEvent', () {
    test('creates with required parameters', () {
      final task = Task(
        id: 'test',
        type: TaskType.llm,
        execute: () async => 'result',
      );

      final event = TaskEvent(
        type: TaskEventType.submitted,
        task: task,
      );

      expect(event.type, equals(TaskEventType.submitted));
      expect(event.task, equals(task));
      expect(event.error, isNull);
    });

    test('creates with error', () {
      final task = Task(
        id: 'test',
        type: TaskType.llm,
        execute: () async => 'result',
      );

      final event = TaskEvent(
        type: TaskEventType.failed,
        task: task,
        error: Exception('test_error'),
      );

      expect(event.error, isNotNull);
    });
  });

  group('TaskEventType', () {
    test('has all expected types', () {
      expect(TaskEventType.values, contains(TaskEventType.submitted));
      expect(TaskEventType.values, contains(TaskEventType.started));
      expect(TaskEventType.values, contains(TaskEventType.completed));
      expect(TaskEventType.values, contains(TaskEventType.failed));
      expect(TaskEventType.values, contains(TaskEventType.cancelled));
      expect(TaskEventType.values, contains(TaskEventType.timeout));
    });
  });

  group('TaskCancelledException', () {
    test('toString returns formatted message', () {
      final exception = TaskCancelledException('task_123');
      expect(exception.toString(), equals('Task cancelled: task_123'));
    });
  });

  group('TaskTimeoutException', () {
    test('toString returns formatted message', () {
      final exception = TaskTimeoutException('task_123');
      expect(exception.toString(), equals('Task timeout: task_123'));
    });
  });
}
