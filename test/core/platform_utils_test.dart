import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/core/platform_utils.dart';

void main() {
  group('PlatformUtils', () {
    test('platformName is not empty', () {
      expect(PlatformUtils.platformName, isNotEmpty);
    });

    test('isMobile is either true or false', () {
      expect(PlatformUtils.isMobile, anyOf(isTrue, isFalse));
    });

    test('isDesktop is either true or false', () {
      expect(PlatformUtils.isDesktop, anyOf(isTrue, isFalse));
    });

    test('isIOS is either true or false', () {
      expect(PlatformUtils.isIOS, anyOf(isTrue, isFalse));
    });

    test('isAndroid is either true or false', () {
      expect(PlatformUtils.isAndroid, anyOf(isTrue, isFalse));
    });

    test('isMacOS is either true or false', () {
      expect(PlatformUtils.isMacOS, anyOf(isTrue, isFalse));
    });

    test('isWindows is either true or false', () {
      expect(PlatformUtils.isWindows, anyOf(isTrue, isFalse));
    });

    test('isLinux is either true or false', () {
      expect(PlatformUtils.isLinux, anyOf(isTrue, isFalse));
    });

    test('mobile implies not desktop', () {
      if (PlatformUtils.isMobile) {
        expect(PlatformUtils.isDesktop, isFalse);
      }
    });

    test('desktop implies not mobile', () {
      if (PlatformUtils.isDesktop) {
        expect(PlatformUtils.isMobile, isFalse);
      }
    });
  });
}
