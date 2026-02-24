/// 日志级别
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

extension LogLevelExtension on LogLevel {
  String get name {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  int get priority {
    switch (this) {
      case LogLevel.debug:
        return 0;
      case LogLevel.info:
        return 1;
      case LogLevel.warning:
        return 2;
      case LogLevel.error:
        return 3;
    }
  }
}

/// 日志工具
class Logger {
  static Logger? _instance;
  static LogLevel _minLevel = LogLevel.info;

  Logger._();

  static Logger get instance {
    _instance ??= Logger._();
    return _instance!;
  }

  /// 设置最小日志级别
  static void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  /// Debug 日志
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, message, error, stackTrace);
  }

  /// Info 日志
  void info(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.info, message, error, stackTrace);
  }

  /// Warning 日志
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, message, error, stackTrace);
  }

  /// Error 日志
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  void _log(
    LogLevel level,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    if (level.priority < _minLevel.priority) return;

    final timestamp = DateTime.now().toIso8601String().split('T')[1].split('.')[0];
    final prefix = '[$timestamp] [${level.name}]';

    if (error != null) {
      print('$prefix $message\nError: $error');
    } else {
      print('$prefix $message');
    }

    if (stackTrace != null && level == LogLevel.error) {
      print(stackTrace);
    }
  }
}

/// 全局日志实例
final logger = Logger.instance;
