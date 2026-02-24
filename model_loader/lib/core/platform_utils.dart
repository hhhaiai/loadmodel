import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 平台工具类
class PlatformUtils {
  PlatformUtils._();

  /// 是否为移动端
  static bool get isMobile => Platform.isIOS || Platform.isAndroid;

  /// 是否为桌面端
  static bool get isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  /// 是否为 Apple 平台
  static bool get isApple => Platform.isIOS || Platform.isMacOS;

  /// 是否支持量化 (仅桌面端)
  static bool get supportsQuantization =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  /// 获取当前平台名称
  static String get platformName {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// 是否为 iOS
  static bool get isIOS => Platform.isIOS;

  /// 是否为 Android
  static bool get isAndroid => Platform.isAndroid;

  /// 是否为 macOS
  static bool get isMacOS => Platform.isMacOS;

  /// 是否为 Windows
  static bool get isWindows => Platform.isWindows;

  /// 是否为 Linux
  static bool get isLinux => Platform.isLinux;

  /// 获取模型缓存目录
  static Future<String> getDefaultCacheDir() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    } catch (e) {
      return './models';
    }
  }

  /// 获取模型缓存目录 (同步版本)
  static String getDefaultCacheDirSync() {
    // 使用相对路径，避免权限问题
    return './models';
  }

  /// 获取自定义模型默认目录
  static Future<String> getDefaultCustomModelDir() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/Models';
    } catch (e) {
      return './custom_models';
    }
  }

  /// 获取自定义模型目录 (同步版本)
  static String getDefaultCustomModelDirSync() {
    // 使用相对路径
    return './custom_models';
  }
}
