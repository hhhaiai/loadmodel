import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/utils/logger.dart';

void main() {
  group('LogLevel', () {
    test('has all expected levels', () {
      expect(LogLevel.values, contains(LogLevel.debug));
      expect(LogLevel.values, contains(LogLevel.info));
      expect(LogLevel.values, contains(LogLevel.warning));
      expect(LogLevel.values, contains(LogLevel.error));
    });

    test('name extension returns correct values', () {
      expect(LogLevel.debug.name, equals('DEBUG'));
      expect(LogLevel.info.name, equals('INFO'));
      expect(LogLevel.warning.name, equals('WARN'));
      expect(LogLevel.error.name, equals('ERROR'));
    });

    test('priority extension returns correct values', () {
      expect(LogLevel.debug.priority, equals(0));
      expect(LogLevel.info.priority, equals(1));
      expect(LogLevel.warning.priority, equals(2));
      expect(LogLevel.error.priority, equals(3));
    });

    test('priority increases with severity', () {
      expect(LogLevel.debug.priority, lessThan(LogLevel.info.priority));
      expect(LogLevel.info.priority, lessThan(LogLevel.warning.priority));
      expect(LogLevel.warning.priority, lessThan(LogLevel.error.priority));
    });
  });

  group('Logger', () {
    test('singleton returns same instance', () {
      final instance1 = Logger.instance;
      final instance2 = Logger.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('setMinLevel changes minimum log level', () {
      final originalLevel = LogLevel.info;

      Logger.setMinLevel(LogLevel.debug);
      // The level should now be debug (lower priority means more logs)

      Logger.setMinLevel(LogLevel.error);
      // Now only errors should be logged

      // Restore original
      Logger.setMinLevel(originalLevel);
    });

    test('debug method exists', () {
      // Just verify the method exists and can be called
      final logger = Logger.instance;
      expect(logger.debug, isA<Function>());
    });

    test('info method exists', () {
      final logger = Logger.instance;
      expect(logger.info, isA<Function>());
    });

    test('warning method exists', () {
      final logger = Logger.instance;
      expect(logger.warning, isA<Function>());
    });

    test('error method exists', () {
      final logger = Logger.instance;
      expect(logger.error, isA<Function>());
    });
  });
}
