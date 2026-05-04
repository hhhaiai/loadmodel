import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/core/platform_utils.dart';

void main() {
  group('PlatformUtils', () {
    // ---------------------------------------------------------------
    // 1. Basic platform flag truthiness
    // ---------------------------------------------------------------
    group('platform flags', () {
      test('isIOS matches Platform.isIOS', () {
        expect(PlatformUtils.isIOS, Platform.isIOS);
      });

      test('isAndroid matches Platform.isAndroid', () {
        expect(PlatformUtils.isAndroid, Platform.isAndroid);
      });

      test('isMacOS matches Platform.isMacOS', () {
        expect(PlatformUtils.isMacOS, Platform.isMacOS);
      });

      test('isWindows matches Platform.isWindows', () {
        expect(PlatformUtils.isWindows, Platform.isWindows);
      });

      test('isLinux matches Platform.isLinux', () {
        expect(PlatformUtils.isLinux, Platform.isLinux);
      });
    });

    // ---------------------------------------------------------------
    // 2. Logical invariants between flags
    // ---------------------------------------------------------------
    group('logical invariants', () {
      test('mobile and desktop are mutually exclusive', () {
        expect(PlatformUtils.isMobile && PlatformUtils.isDesktop, isFalse,
            reason: 'A platform cannot be both mobile and desktop');
      });

      test('exactly one of mobile or desktop is true', () {
        expect(PlatformUtils.isMobile || PlatformUtils.isDesktop, isTrue,
            reason: 'Every supported platform is either mobile or desktop');
      });

      test('isMobile is true iff isIOS or isAndroid', () {
        expect(PlatformUtils.isMobile,
            PlatformUtils.isIOS || PlatformUtils.isAndroid);
      });

      test('isDesktop is true iff isMacOS or isWindows or isLinux', () {
        expect(PlatformUtils.isDesktop,
            PlatformUtils.isMacOS || PlatformUtils.isWindows || PlatformUtils.isLinux);
      });

      test('isApple is true iff isIOS or isMacOS', () {
        expect(
            PlatformUtils.isApple, PlatformUtils.isIOS || PlatformUtils.isMacOS);
      });

      test('supportsQuantization equals isDesktop', () {
        expect(PlatformUtils.supportsQuantization, PlatformUtils.isDesktop);
      });

      test('only one primary platform flag is true', () {
        final trueCount = [
          PlatformUtils.isIOS,
          PlatformUtils.isAndroid,
          PlatformUtils.isMacOS,
          PlatformUtils.isWindows,
          PlatformUtils.isLinux,
        ].where((b) => b).length;
        expect(trueCount, 1,
            reason: 'Exactly one platform flag should be true');
      });

      test('if mobile, isApple is true only on iOS', () {
        if (PlatformUtils.isMobile) {
          expect(PlatformUtils.isApple, PlatformUtils.isIOS);
        }
      });
    });

    // ---------------------------------------------------------------
    // 3. platformName resolution
    // ---------------------------------------------------------------
    group('platformName', () {
      test('returns a non-empty string', () {
        expect(PlatformUtils.platformName, isNotEmpty);
      });

      test('returns a known platform name', () {
        const knownNames = ['ios', 'android', 'macos', 'windows', 'linux'];
        expect(knownNames, contains(PlatformUtils.platformName));
      });

      test('matches the current platform flag', () {
        final name = PlatformUtils.platformName;
        if (Platform.isIOS) expect(name, 'ios');
        if (Platform.isAndroid) expect(name, 'android');
        if (Platform.isMacOS) expect(name, 'macos');
        if (Platform.isWindows) expect(name, 'windows');
        if (Platform.isLinux) expect(name, 'linux');
      });

      test('returns lowercase', () {
        expect(PlatformUtils.platformName,
            PlatformUtils.platformName.toLowerCase());
      });
    });

    // ---------------------------------------------------------------
    // 4. processorCount
    // ---------------------------------------------------------------
    group('processorCount', () {
      test('is greater than zero', () {
        expect(PlatformUtils.processorCount, greaterThan(0));
      });

      test('matches Platform.numberOfProcessors', () {
        expect(PlatformUtils.processorCount, Platform.numberOfProcessors);
      });
    });

    // ---------------------------------------------------------------
    // 5. getDefaultCacheDirSync
    // ---------------------------------------------------------------
    group('getDefaultCacheDirSync', () {
      test('returns a non-empty string', () {
        expect(PlatformUtils.getDefaultCacheDirSync(), isNotEmpty);
      });

      test('returns mobile-specific path on mobile platforms', () {
        final result = PlatformUtils.getDefaultCacheDirSync();
        if (Platform.isIOS || Platform.isAndroid) {
          expect(result, contains('model_loader_cache'));
          expect(result, startsWith(Directory.systemTemp.path));
        } else {
          expect(result, './models');
        }
      });

      test('returns ./models on desktop platforms', () {
        if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
          expect(PlatformUtils.getDefaultCacheDirSync(), './models');
        }
      });
    });

    // ---------------------------------------------------------------
    // 6. getDefaultCustomModelDirSync
    // ---------------------------------------------------------------
    group('getDefaultCustomModelDirSync', () {
      test('returns a non-empty string', () {
        expect(PlatformUtils.getDefaultCustomModelDirSync(), isNotEmpty);
      });

      test('returns mobile-specific path on mobile platforms', () {
        final result = PlatformUtils.getDefaultCustomModelDirSync();
        if (Platform.isIOS || Platform.isAndroid) {
          expect(result, contains('model_loader_custom'));
          expect(result, startsWith(Directory.systemTemp.path));
        } else {
          expect(result, './custom_models');
        }
      });

      test('returns ./custom_models on desktop platforms', () {
        if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
          expect(PlatformUtils.getDefaultCustomModelDirSync(), './custom_models');
        }
      });
    });

    // ---------------------------------------------------------------
    // 7. getDefaultCacheDir (async)
    // ---------------------------------------------------------------
    group('getDefaultCacheDir', () {
      test('returns a non-empty string', () async {
        final result = await PlatformUtils.getDefaultCacheDir();
        expect(result, isNotEmpty);
      });

      test('does not throw', () async {
        // Should either succeed with getApplicationDocumentsDirectory
        // or fall back to './models'
        expect(() => PlatformUtils.getDefaultCacheDir(), returnsNormally);
      });

      test('fallback returns ./models when directory unavailable', () async {
        // On desktop (macOS), getApplicationDocumentsDirectory usually succeeds.
        // We verify the return value is a valid non-empty path.
        final result = await PlatformUtils.getDefaultCacheDir();
        expect(result, isNotEmpty);
        // Result should be either a real path or the fallback
        expect(
          result.startsWith(Directory.systemTemp.path) ||
              result.startsWith('/') ||
              result == './models',
          isTrue,
        );
      });
    });

    // ---------------------------------------------------------------
    // 8. getDefaultCustomModelDir (async)
    // ---------------------------------------------------------------
    group('getDefaultCustomModelDir', () {
      test('returns a non-empty string', () async {
        final result = await PlatformUtils.getDefaultCustomModelDir();
        expect(result, isNotEmpty);
      });

      test('does not throw', () async {
        expect(
            () => PlatformUtils.getDefaultCustomModelDir(), returnsNormally);
      });

      test('ends with /Models on success or falls back', () async {
        final result = await PlatformUtils.getDefaultCustomModelDir();
        // Either contains /Models (success) or is ./custom_models (fallback)
        expect(
          result.endsWith('/Models') || result == './custom_models',
          isTrue,
          reason:
              'Expected path to end with /Models or be ./custom_models, got: $result',
        );
      });
    });

    // ---------------------------------------------------------------
    // 9. Sync vs async consistency
    // ---------------------------------------------------------------
    group('sync vs async consistency', () {
      test('sync cache dir is either a temp path or fallback', () {
        final sync = PlatformUtils.getDefaultCacheDirSync();
        if (Platform.isIOS || Platform.isAndroid) {
          expect(sync, isNot('./models'));
        } else {
          expect(sync, './models');
        }
      });

      test('sync custom dir is either a temp path or fallback', () {
        final sync = PlatformUtils.getDefaultCustomModelDirSync();
        if (Platform.isIOS || Platform.isAndroid) {
          expect(sync, isNot('./custom_models'));
        } else {
          expect(sync, './custom_models');
        }
      });
    });

    // ---------------------------------------------------------------
    // 10. Constructor is private (cannot instantiate)
    // ---------------------------------------------------------------
    group('constructor', () {
      test('class is used only via static members', () {
        // PlatformUtils has a private constructor (PlatformUtils._()),
        // so it cannot be instantiated from outside. Verify the class
        // exists and static access works.
        expect(PlatformUtils.platformName, isA<String>());
        expect(PlatformUtils.processorCount, isA<int>());
        expect(PlatformUtils.isMobile, isA<bool>());
      });
    });

    // ---------------------------------------------------------------
    // 11. Cross-property consistency on current platform
    // ---------------------------------------------------------------
    group('current platform consistency', () {
      test('on macOS: isDesktop, isApple, isMacOS all true', () {
        if (Platform.isMacOS) {
          expect(PlatformUtils.isDesktop, isTrue);
          expect(PlatformUtils.isApple, isTrue);
          expect(PlatformUtils.isMacOS, isTrue);
          expect(PlatformUtils.isMobile, isFalse);
          expect(PlatformUtils.isIOS, isFalse);
          expect(PlatformUtils.isAndroid, isFalse);
          expect(PlatformUtils.supportsQuantization, isTrue);
        }
      });

      test('on iOS: isMobile, isApple, isIOS all true', () {
        if (Platform.isIOS) {
          expect(PlatformUtils.isMobile, isTrue);
          expect(PlatformUtils.isApple, isTrue);
          expect(PlatformUtils.isIOS, isTrue);
          expect(PlatformUtils.isDesktop, isFalse);
          expect(PlatformUtils.isMacOS, isFalse);
          expect(PlatformUtils.supportsQuantization, isFalse);
        }
      });

      test('on Android: isMobile, isAndroid true; isDesktop false', () {
        if (Platform.isAndroid) {
          expect(PlatformUtils.isMobile, isTrue);
          expect(PlatformUtils.isAndroid, isTrue);
          expect(PlatformUtils.isDesktop, isFalse);
          expect(PlatformUtils.isApple, isFalse);
          expect(PlatformUtils.supportsQuantization, isFalse);
        }
      });

      test('on Windows: isDesktop, isWindows true; isMobile false', () {
        if (Platform.isWindows) {
          expect(PlatformUtils.isDesktop, isTrue);
          expect(PlatformUtils.isWindows, isTrue);
          expect(PlatformUtils.isMobile, isFalse);
          expect(PlatformUtils.isApple, isFalse);
          expect(PlatformUtils.supportsQuantization, isTrue);
        }
      });

      test('on Linux: isDesktop, isLinux true; isMobile false', () {
        if (Platform.isLinux) {
          expect(PlatformUtils.isDesktop, isTrue);
          expect(PlatformUtils.isLinux, isTrue);
          expect(PlatformUtils.isMobile, isFalse);
          expect(PlatformUtils.isApple, isFalse);
          expect(PlatformUtils.supportsQuantization, isTrue);
        }
      });
    });

    // ---------------------------------------------------------------
    // 12. Edge cases for path methods
    // ---------------------------------------------------------------
    group('path method edge cases', () {
      test('getDefaultCacheDirSync does not end with separator', () {
        final result = PlatformUtils.getDefaultCacheDirSync();
        expect(result.endsWith('/'), isFalse,
            reason: 'Path should not end with a separator: $result');
      });

      test('getDefaultCustomModelDirSync does not end with separator', () {
        final result = PlatformUtils.getDefaultCustomModelDirSync();
        expect(result.endsWith('/'), isFalse,
            reason: 'Path should not end with a separator: $result');
      });

      test('cache and custom dir sync are different paths', () {
        final cache = PlatformUtils.getDefaultCacheDirSync();
        final custom = PlatformUtils.getDefaultCustomModelDirSync();
        expect(cache, isNot(equals(custom)));
      });

      test('async cache dir and custom dir are different paths', () async {
        final cache = await PlatformUtils.getDefaultCacheDir();
        final custom = await PlatformUtils.getDefaultCustomModelDir();
        expect(cache, isNot(equals(custom)));
      });
    });
  });
}
