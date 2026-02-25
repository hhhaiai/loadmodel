import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';

/// Asset 文件助手 - 用于将 Flutter bundle 中的模型文件复制到可访问的位置
class AssetHelper {
  static final AssetHelper _instance = AssetHelper._internal();
  factory AssetHelper() => _instance;
  AssetHelper._internal();

  final Map<String, String> _pathCache = {};

  /// 获取应用缓存目录
  Future<String> get cacheDir async {
    final dir = await getApplicationCacheDirectory();
    return dir.path;
  }

  /// 获取模型目录
  Future<String> get modelsDir async {
    final dir = await Directory('${await cacheDir}/models').create(recursive: true);
    return dir.path;
  }

  /// 从 assets 加载模型文件到缓存目录
  /// 返回缓存后的文件路径
  Future<String> loadAssetToCache(String assetPath, {String? filename}) async {
    // 检查缓存
    if (_pathCache.containsKey(assetPath)) {
      final cachedPath = _pathCache[assetPath]!;
      if (await File(cachedPath).exists()) {
        return cachedPath;
      }
    }

    try {
      // 确定目标文件名
      final name = filename ?? assetPath.split('/').last;
      final targetDir = await modelsDir;
      final targetPath = '$targetDir/$name';

      // 检查目标文件是否已存在
      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        logger.info('Asset already exists at: $targetPath');
        _pathCache[assetPath] = targetPath;
        return targetPath;
      }

      // 从 assets 复制到缓存
      logger.info('Loading asset: $assetPath');
      final ByteData data = await rootBundle.load(assetPath);
      final List<int> bytes = data.buffer.asUint8List();

      await targetFile.writeAsBytes(bytes);
      logger.info('Asset copied to: $targetPath');

      _pathCache[assetPath] = targetPath;
      return targetPath;
    } catch (e) {
      logger.error('Failed to load asset: $assetPath', e);
      rethrow;
    }
  }

  /// 批量加载模型相关文件
  Future<Map<String, String>> loadModelAssets({
    required String modelDir,
    String? modelFile,
    String? tokenizerFile,
  }) async {
    final results = <String, String>{};
    final basePath = 'assets/models/$modelDir';

    if (modelFile != null) {
      try {
        results['modelPath'] = await loadAssetToCache('$basePath/$modelFile');
      } catch (e) {
        logger.warning('Model file not found: $basePath/$modelFile');
      }
    }

    if (tokenizerFile != null) {
      try {
        results['tokenizerPath'] = await loadAssetToCache('$basePath/$tokenizerFile');
      } catch (e) {
        logger.warning('Tokenizer file not found: $basePath/$tokenizerFile');
      }
    }

    return results;
  }

  /// 清理缓存的模型文件
  Future<void> clearCache() async {
    final dir = await getApplicationCacheDirectory();
    final modelsPath = '${dir.path}/models';

    try {
      final modelsDir = Directory(modelsPath);
      if (await modelsDir.exists()) {
        await modelsDir.delete(recursive: true);
        logger.info('Model cache cleared');
      }
    } catch (e) {
      logger.error('Failed to clear cache', e);
    }

    _pathCache.clear();
  }

  /// 获取缓存大小（字节）
  Future<int> getCacheSize() async {
    int totalSize = 0;
    final modelsPath = '${await cacheDir}/models';

    try {
      final dir = Directory(modelsPath);
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (e) {
      logger.error('Failed to calculate cache size', e);
    }

    return totalSize;
  }
}
