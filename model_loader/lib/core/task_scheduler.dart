/// TaskScheduler - Task scheduling and execution
/// Reference: CLAUDE.md Section 7

import 'dart:async';

/// Task priority levels
enum TaskPriority {
  /// Low priority (background tasks)
  low(0),

  /// Normal priority
  normal(1),

  /// High priority (user-initiated)
  high(2),

  /// Critical priority (foreground tasks)
  critical(3);

  final int value;
  const TaskPriority(this.value);
}

/// Resource type annotation
enum ResourceType {
  /// CPU bound task
  cpuBound,

  /// GPU bound task
  gpuBound,

  /// IO bound task (network, disk)
  ioBound,
}

/// Task type
enum TaskType {
  /// LLM inference
  llm,

  /// OCR inference
  ocr,

  /// STT inference
  stt,

  /// TTS inference
  tts,

  /// Embedding inference
  embedding,

  /// Model download
  download,

  /// Model verification
  verify,

  /// Other
  other,
}

/// Task status
enum TaskStatus {
  /// Waiting in queue
  pending,

  /// Currently executing
  running,

  /// Completed successfully
  completed,

  /// Failed with error
  failed,

  /// Cancelled by user
  cancelled,

  /// Timeout
  timeout,
}

/// Task definition
class Task {
  /// Unique task ID
  final String id;

  /// Task type
  final TaskType type;

  /// Task priority
  final TaskPriority priority;

  /// Resource type
  final ResourceType resourceType;

  /// Task execution function
  final Future<dynamic> Function() execute;

  /// Timeout duration
  final Duration? timeout;

  /// Whether task can be cancelled
  final bool cancellable;

  /// Task metadata
  final Map<String, dynamic>? metadata;

  /// Current status
  TaskStatus status;

  /// Result
  dynamic result;

  /// Error if failed
  Object? error;

  /// Created timestamp
  final DateTime createdAt;

  /// Started timestamp
  DateTime? startedAt;

  /// Completed timestamp
  DateTime? completedAt;

  /// Cancel callback
  void Function()? _onCancel;

  Task({
    required this.id,
    required this.type,
    this.priority = TaskPriority.normal,
    this.resourceType = ResourceType.cpuBound,
    required this.execute,
    this.timeout,
    this.cancellable = true,
    this.metadata,
    this.status = TaskStatus.pending,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Set cancel callback
  void setCancelCallback(void Function() callback) {
    _onCancel = callback;
  }

  /// Cancel this task
  void cancel() {
    if (cancellable && status == TaskStatus.pending) {
      status = TaskStatus.cancelled;
      _onCancel?.call();
    }
  }

  /// Check if task is done
  bool get isDone =>
      status == TaskStatus.completed ||
      status == TaskStatus.failed ||
      status == TaskStatus.cancelled ||
      status == TaskStatus.timeout;
}

/// Queue configuration for a task type
class QueueConfig {
  /// Maximum concurrent tasks
  final int maxConcurrent;

  /// Whether to allow new tasks when queue is full
  final bool rejectOnFull;

  const QueueConfig({
    this.maxConcurrent = 1,
    this.rejectOnFull = false,
  });
}

/// Default queue configurations (per CLAUDE.md Section 7)
class DefaultQueueConfigs {
  static const QueueConfig llm = QueueConfig(maxConcurrent: 1);
  static const QueueConfig ocr = QueueConfig(maxConcurrent: 2);
  static const QueueConfig stt = QueueConfig(maxConcurrent: 2);
  static const QueueConfig tts = QueueConfig(maxConcurrent: 1);
  static const QueueConfig embedding = QueueConfig(maxConcurrent: 2);
  static const QueueConfig download = QueueConfig(maxConcurrent: 3);
  static const QueueConfig verify = QueueConfig(maxConcurrent: 2);

  static QueueConfig forType(TaskType type) {
    switch (type) {
      case TaskType.llm:
        return llm;
      case TaskType.ocr:
        return ocr;
      case TaskType.stt:
        return stt;
      case TaskType.tts:
        return tts;
      case TaskType.embedding:
        return embedding;
      case TaskType.download:
        return download;
      case TaskType.verify:
        return verify;
      case TaskType.other:
        return const QueueConfig(maxConcurrent: 1);
    }
  }
}

/// Task scheduler statistics
class SchedulerStats {
  /// Total tasks submitted
  final int totalSubmitted;

  /// Total tasks completed
  final int totalCompleted;

  /// Total tasks failed
  final int totalFailed;

  /// Total tasks cancelled
  final int totalCancelled;

  /// Total tasks timed out
  final int totalTimeout;

  /// Current pending tasks
  final int pendingCount;

  /// Current running tasks
  final int runningCount;

  const SchedulerStats({
    this.totalSubmitted = 0,
    this.totalCompleted = 0,
    this.totalFailed = 0,
    this.totalCancelled = 0,
    this.totalTimeout = 0,
    this.pendingCount = 0,
    this.runningCount = 0,
  });
}

/// TaskScheduler - manages task execution with priorities and queues
class TaskScheduler {
  /// Singleton instance
  static TaskScheduler? _instance;

  /// Get singleton instance
  static TaskScheduler get instance {
    _instance ??= TaskScheduler._();
    return _instance!;
  }

  TaskScheduler._();

  /// Queue configurations
  final Map<TaskType, QueueConfig> _queueConfigs = {};

  /// Task queues (pending tasks)
  final Map<TaskType, List<Task>> _queues = {};

  /// Running tasks
  final Map<String, Task> _runningTasks = {};

  /// Completed tasks (for results)
  final Map<String, Task> _completedTasks = {};

  /// Scheduler statistics
  int _totalSubmitted = 0;
  int _totalCompleted = 0;
  int _totalFailed = 0;
  int _totalCancelled = 0;
  int _totalTimeout = 0;

  /// Maximum total concurrent tasks
  int _maxTotalConcurrent = 4;

  /// Stream controller for task events
  final _eventController = StreamController<TaskEvent>.broadcast();

  /// Get task event stream
  Stream<TaskEvent> get events => _eventController.stream;

  /// Initialize scheduler with custom queue configs
  void initialize({
    Map<TaskType, QueueConfig>? queueConfigs,
    int maxTotalConcurrent = 4,
  }) {
    _maxTotalConcurrent = maxTotalConcurrent;

    // Set default configs
    for (final type in TaskType.values) {
      _queueConfigs[type] = queueConfigs?[type] ?? DefaultQueueConfigs.forType(type);
      _queues[type] = [];
    }
  }

  /// Submit a task for execution (per CLAUDE.md Section 7.1)
  /// Returns: Future that resolves with result or throws error
  Future<dynamic> submit({
    required TaskType type,
    required Future<dynamic> Function() execute,
    TaskPriority priority = TaskPriority.normal,
    ResourceType resourceType = ResourceType.cpuBound,
    Duration? timeout,
    bool cancellable = true,
    Map<String, dynamic>? metadata,
  }) async {
    final taskId = 'task_${DateTime.now().millisecondsSinceEpoch}_$_totalSubmitted';

    final task = Task(
      id: taskId,
      type: type,
      priority: priority,
      resourceType: resourceType,
      execute: execute,
      timeout: timeout,
      cancellable: cancellable,
      metadata: metadata,
    );

    _totalSubmitted++;

    // Emit task submitted event
    _emitEvent(TaskEvent(
      type: TaskEventType.submitted,
      task: task,
    ));

    // Add to queue
    _addToQueue(task);

    // Try to start if possible
    _tryStartNext(type);

    // Return future that completes when task does
    return _waitForTask(task);
  }

  /// Add task to appropriate queue
  void _addToQueue(Task task) {
    final queue = _queues[task.type] ?? [];
    queue.add(task);

    // Sort by priority (higher priority first)
    queue.sort((a, b) => b.priority.value.compareTo(a.priority.value));
  }

  /// Try to start next task in queue
  void _tryStartNext(TaskType type) {
    final config = _queueConfigs[type];
    if (config == null) return;

    // Check max concurrent for this type
    final runningInType = _runningTasks.values
        .where((t) => t.type == type && t.status == TaskStatus.running)
        .length;

    if (runningInType >= config.maxConcurrent) return;

    // Check total max concurrent
    if (_runningTasks.length >= _maxTotalConcurrent) return;

    // Get next pending task
    final queue = _queues[type];
    if (queue == null || queue.isEmpty) return;

    final task = queue.firstWhere(
      (t) => t.status == TaskStatus.pending,
      orElse: () => queue.first,
    );

    if (task.status != TaskStatus.pending) return;

    // Start task
    _startTask(task);
  }

  /// Start a task
  Future<void> _startTask(Task task) async {
    task.status = TaskStatus.running;
    task.startedAt = DateTime.now();
    _runningTasks[task.id] = task;

    _emitEvent(TaskEvent(
      type: TaskEventType.started,
      task: task,
    ));

    // Setup timeout
    Timer? timeoutTimer;
    if (task.timeout != null) {
      timeoutTimer = Timer(task.timeout!, () {
        _handleTaskTimeout(task);
      });
    }

    try {
      // Execute task
      task.result = await task.execute();
      task.status = TaskStatus.completed;
      task.completedAt = DateTime.now();
      _totalCompleted++;

      _emitEvent(TaskEvent(
        type: TaskEventType.completed,
        task: task,
      ));
    } catch (e) {
      if (task.status != TaskStatus.cancelled &&
          task.status != TaskStatus.timeout) {
        task.status = TaskStatus.failed;
        task.error = e;
        task.completedAt = DateTime.now();
        _totalFailed++;

        _emitEvent(TaskEvent(
          type: TaskEventType.failed,
          task: task,
          error: e,
        ));
      }
    } finally {
      timeoutTimer?.cancel();
      _runningTasks.remove(task.id);
      _completedTasks[task.id] = task;

      // Try to start next task in same queue
      _tryStartNext(task.type);

      // Also try download queue (to prevent IO blocking inference)
      if (task.type != TaskType.download) {
        _tryStartNext(TaskType.download);
      }
    }
  }

  /// Handle task timeout
  void _handleTaskTimeout(Task task) {
    if (task.status == TaskStatus.running) {
      task.status = TaskStatus.timeout;
      task.completedAt = DateTime.now();
      _totalTimeout++;

      _emitEvent(TaskEvent(
        type: TaskEventType.timeout,
        task: task,
      ));
    }
  }

  /// Wait for task completion
  Future<dynamic> _waitForTask(Task task) async {
    while (!task.isDone) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    switch (task.status) {
      case TaskStatus.completed:
        return task.result;
      case TaskStatus.failed:
        throw task.error ?? Exception('Task failed');
      case TaskStatus.cancelled:
        throw TaskCancelledException(task.id);
      case TaskStatus.timeout:
        throw TaskTimeoutException(task.id);
      default:
        throw Exception('Unknown task status: ${task.status}');
    }
  }

  /// Cancel a task by ID (per CLAUDE.md Section 7.2)
  bool cancelTask(String taskId) {
    final task = _runningTasks[taskId] ??
        _completedTasks[taskId] ??
        _queues.values
            .expand((q) => q)
            .firstWhere((t) => t.id == taskId, orElse: () => throw ArgumentError('Task not found'));

    if (!task.cancellable) return false;

    if (task.status == TaskStatus.pending) {
      task.status = TaskStatus.cancelled;
      task.completedAt = DateTime.now();
      _totalCancelled++;

      _emitEvent(TaskEvent(
        type: TaskEventType.cancelled,
        task: task,
      ));

      return true;
    }

    return false;
  }

  /// Get task status
  TaskStatus? getTaskStatus(String taskId) {
    final task = _runningTasks[taskId] ??
        _completedTasks[taskId] ??
        _queues.values
            .expand((q) => q)
            .firstWhere((t) => t.id == taskId, orElse: () => throw ArgumentError('Task not found'));

    return task.status;
  }

  /// Get scheduler statistics
  SchedulerStats getStats() {
    return SchedulerStats(
      totalSubmitted: _totalSubmitted,
      totalCompleted: _totalCompleted,
      totalFailed: _totalFailed,
      totalCancelled: _totalCancelled,
      totalTimeout: _totalTimeout,
      pendingCount: _queues.values.expand((q) => q).where((t) => t.status == TaskStatus.pending).length,
      runningCount: _runningTasks.length,
    );
  }

  /// Emit task event
  void _emitEvent(TaskEvent event) {
    _eventController.add(event);
  }

  /// Dispose scheduler
  void dispose() {
    _eventController.close();
    _runningTasks.clear();
    _completedTasks.clear();
    for (final queue in _queues.values) {
      queue.clear();
    }
  }
}

/// Task event types
enum TaskEventType {
  submitted,
  started,
  completed,
  failed,
  cancelled,
  timeout,
}

/// Task event
class TaskEvent {
  final TaskEventType type;
  final Task task;
  final Object? error;

  const TaskEvent({
    required this.type,
    required this.task,
    this.error,
  });
}

/// Task cancelled exception
class TaskCancelledException implements Exception {
  final String taskId;
  TaskCancelledException(this.taskId);

  @override
  String toString() => 'Task cancelled: $taskId';
}

/// Task timeout exception
class TaskTimeoutException implements Exception {
  final String taskId;
  TaskTimeoutException(this.taskId);

  @override
  String toString() => 'Task timeout: $taskId';
}

// ============================================================
// Convenience methods
// ============================================================

extension TaskSchedulerExtension on TaskScheduler {
  /// Submit LLM task
  Future<dynamic> submitLLM(Future<dynamic> Function() execute, {
    TaskPriority priority = TaskPriority.normal,
    Duration? timeout,
    bool cancellable = true,
  }) {
    return submit(
      type: TaskType.llm,
      execute: execute,
      priority: priority,
      resourceType: ResourceType.cpuBound,
      timeout: timeout,
      cancellable: cancellable,
    );
  }

  /// Submit OCR task
  Future<dynamic> submitOCR(Future<dynamic> Function() execute, {
    TaskPriority priority = TaskPriority.normal,
    Duration? timeout,
    bool cancellable = true,
  }) {
    return submit(
      type: TaskType.ocr,
      execute: execute,
      priority: priority,
      resourceType: ResourceType.cpuBound,
      timeout: timeout,
      cancellable: cancellable,
    );
  }

  /// Submit download task
  Future<dynamic> submitDownload(Future<dynamic> Function() execute, {
    TaskPriority priority = TaskPriority.low,
    Duration? timeout,
    bool cancellable = true,
  }) {
    return submit(
      type: TaskType.download,
      execute: execute,
      priority: priority,
      resourceType: ResourceType.ioBound,
      timeout: timeout,
      cancellable: cancellable,
    );
  }
}
