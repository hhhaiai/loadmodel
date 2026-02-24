/// 下载进度
class DownloadProgress {
  /// 模型ID
  final String modelId;

  /// 已下载字节数
  final int received;

  /// 总字节数
  final int total;

  /// 下载速度 (bytes/s)
  final double speed;

  /// 进度 (0.0 - 1.0)
  double get progress => total > 0 ? received / total : 0.0;

  /// 进度百分比
  int get percent => (progress * 100).round();

  /// 格式化进度
  String get formattedProgress => '$percent%';

  /// 格式化已下载大小
  String get formattedReceived => _formatBytes(received);

  /// 格式化总大小
  String get formattedTotal => _formatBytes(total);

  /// 格式化速度
  String get formattedSpeed => '${_formatBytes(speed.toInt())}/s';

  const DownloadProgress({
    required this.modelId,
    required this.received,
    required this.total,
    this.speed = 0,
  });

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  DownloadProgress copyWith({
    String? modelId,
    int? received,
    int? total,
    double? speed,
  }) {
    return DownloadProgress(
      modelId: modelId ?? this.modelId,
      received: received ?? this.received,
      total: total ?? this.total,
      speed: speed ?? this.speed,
    );
  }
}

/// Install phase (matches CLAUDE.md Section 6.5)
enum InstallPhase {
  /// Initial state
  idle,

  /// Downloading model files
  downloading,

  /// Verifying file integrity
  verifying,

  /// Extracting archive (if applicable)
  extracting,

  /// Ready to use
  ready,

  /// Installation failed
  failed,

  /// Installation cancelled
  cancelled,
}

extension InstallPhaseExtension on InstallPhase {
  String get name {
    switch (this) {
      case InstallPhase.idle:
        return 'idle';
      case InstallPhase.downloading:
        return 'downloading';
      case InstallPhase.verifying:
        return 'verifying';
      case InstallPhase.extracting:
        return 'extracting';
      case InstallPhase.ready:
        return 'ready';
      case InstallPhase.failed:
        return 'failed';
      case InstallPhase.cancelled:
        return 'cancelled';
    }
  }

  bool get isTerminal {
    return this == InstallPhase.ready ||
        this == InstallPhase.failed ||
        this == InstallPhase.cancelled;
  }
}

/// Install progress event (matches CLAUDE.md Section 6.5)
class InstallProgress {
  /// Model ID
  final String modelId;

  /// Model version
  final String version;

  /// Current phase
  final InstallPhase phase;

  /// Bytes received (for downloading phase)
  final int receivedBytes;

  /// Total bytes
  final int totalBytes;

  /// Progress ratio (0.0 - 1.0)
  final double progress;

  /// Request ID for tracking
  final String requestId;

  /// Error information (for failed phase)
  final Map<String, dynamic>? error;

  const InstallProgress({
    required this.modelId,
    required this.version,
    required this.phase,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.progress = 0.0,
    required this.requestId,
    this.error,
  });

  factory InstallProgress.fromJson(Map<String, dynamic> json) {
    return InstallProgress(
      modelId: json['modelId'] ?? '',
      version: json['version'] ?? '1.0.0',
      phase: InstallPhase.values.firstWhere(
        (e) => e.name == json['phase'],
        orElse: () => InstallPhase.idle,
      ),
      receivedBytes: json['receivedBytes'] ?? 0,
      totalBytes: json['totalBytes'] ?? 0,
      progress: (json['progress'] ?? 0.0).toDouble(),
      requestId: json['requestId'] ?? '',
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'modelId': modelId,
      'version': version,
      'phase': phase.name,
      'receivedBytes': receivedBytes,
      'totalBytes': totalBytes,
      'progress': progress,
      'requestId': requestId,
      'error': error,
    };
  }

  InstallProgress copyWith({
    String? modelId,
    String? version,
    InstallPhase? phase,
    int? receivedBytes,
    int? totalBytes,
    double? progress,
    String? requestId,
    Map<String, dynamic>? error,
  }) {
    return InstallProgress(
      modelId: modelId ?? this.modelId,
      version: version ?? this.version,
      phase: phase ?? this.phase,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      progress: progress ?? this.progress,
      requestId: requestId ?? this.requestId,
      error: error ?? this.error,
    );
  }
}

/// Download status (legacy, kept for compatibility)
enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

extension DownloadStatusExtension on DownloadStatus {
  String get displayName {
    switch (this) {
      case DownloadStatus.pending:
        return '等待中';
      case DownloadStatus.downloading:
        return '下载中';
      case DownloadStatus.paused:
        return '已暂停';
      case DownloadStatus.completed:
        return '已完成';
      case DownloadStatus.failed:
        return '下载失败';
      case DownloadStatus.cancelled:
        return '已取消';
    }
  }
}

/// 下载任务
class DownloadTask {
  /// 任务ID
  final String id;

  /// 模型信息
  final String modelId;
  final String modelName;

  /// 保存路径
  final String savePath;

  /// 下载状态
  DownloadStatus status;

  /// 下载进度
  DownloadProgress? progress;

  /// 错误信息
  String? error;

  /// 创建时间
  final DateTime createdAt;

  /// 开始时间
  DateTime? startedAt;

  /// 完成时间
  DateTime? completedAt;

  /// 取消标志
  bool _cancelled = false;

  DownloadTask({
    required this.id,
    required this.modelId,
    required this.modelName,
    required this.savePath,
    this.status = DownloadStatus.pending,
    this.progress,
    this.error,
    DateTime? createdAt,
    this.startedAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
    status = DownloadStatus.cancelled;
  }

  void pause() {
    if (status == DownloadStatus.downloading) {
      status = DownloadStatus.paused;
    }
  }

  void resume() {
    if (status == DownloadStatus.paused) {
      status = DownloadStatus.downloading;
    }
  }
}
