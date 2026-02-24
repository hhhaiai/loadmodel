import 'dart:convert';
import 'dart:io';
import '../models/model_info.dart';
import '../models/model_type.dart';
import '../models/download_task.dart';
import '../utils/logger.dart';
import 'platform_utils.dart';

/// ModelManager - 模型下载/缓存/版本管理
class ModelManager {
  final String _cacheDir;
  final String? _remoteModelListUrl;
  final bool _enableRemoteModels;

  List<ModelInfo> _remoteModels = [];
  List<LocalModel> _localModels = [];

  ModelManager({
    required String cacheDir,
    String? remoteModelListUrl,
    bool enableRemoteModels = true,
  })  : _cacheDir = cacheDir,
        _remoteModelListUrl = remoteModelListUrl,
        _enableRemoteModels = enableRemoteModels;

  /// 初始化
  Future<void> init() async {
    // 尝试创建缓存目录 (在某些平台可能失败)
    try {
      final dir = Directory(_cacheDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      logger.warning('Cannot create cache directory: $e');
    }

    // 加载本地模型列表
    await _loadLocalModels();

    logger.info('ModelManager initialized. Local models: ${_localModels.length}');
  }

  /// 从远程获取模型列表
  Future<List<ModelInfo>> fetchRemoteModels() async {
    if (!_enableRemoteModels || _remoteModelListUrl == null) {
      return [];
    }

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(_remoteModelListUrl!));
      final response = await request.close();

      if (response.statusCode == 200) {
        final content = await response.transform(utf8.decoder).join();
        final json = jsonDecode(content);

        _remoteModels = (json['models'] as List<dynamic>?)
                ?.map((e) => ModelInfo.fromJson(e))
                .toList() ??
            [];

        // 根据当前平台过滤
        _remoteModels = _remoteModels.where((model) {
          final platforms = model.platformReq?.supportedPlatforms ?? [];
          return platforms.isEmpty || platforms.contains(PlatformUtils.platformName);
        }).toList();

        logger.info('Fetched ${_remoteModels.length} remote models');
        return _remoteModels;
      } else {
        logger.warning('Failed to fetch remote models: ${response.statusCode}');
        return [];
      }
    } catch (e, st) {
      logger.error('Error fetching remote models', e, st);
      return [];
    }
  }

  /// 获取本地已下载模型列表
  Future<List<LocalModel>> getLocalModels() async {
    return _localModels;
  }

  /// 获取已缓存的远程模型列表
  List<ModelInfo> get remoteModels => _remoteModels;

  /// 下载模型
  Stream<DownloadProgress> downloadModel(
    ModelInfo model, {
    String? savePath,
  }) async* {
    if (model.downloadUrl == null) {
      throw ArgumentError('Model does not have a download URL');
    }

    final targetPath = savePath ?? '$_cacheDir/${model.id}.${model.format}';
    final file = File(targetPath);

    // 如果文件已存在，跳过下载
    if (await file.exists()) {
      logger.info('Model already exists at $targetPath');
      yield DownloadProgress(
        modelId: model.id,
        received: model.size,
        total: model.size,
      );
      return;
    }

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(model.downloadUrl!));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw HttpException('Download failed with status: ${response.statusCode}');
      }

      final total = response.contentLength ?? model.size;
      var received = 0;
      DateTime? lastUpdate;
      int bytesSinceLastUpdate = 0;

      final sink = file.openWrite();

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        bytesSinceLastUpdate += chunk.length;

        final now = DateTime.now();
        if (lastUpdate == null ||
            now.difference(lastUpdate).inMilliseconds > 500) {
          final elapsed = lastUpdate != null
              ? now.difference(lastUpdate).inMilliseconds / 1000
              : 0;
          final speed = elapsed > 0 ? bytesSinceLastUpdate / elapsed : 0.0;

          yield DownloadProgress(
            modelId: model.id,
            received: received,
            total: total,
            speed: speed,
          );

          lastUpdate = now;
          bytesSinceLastUpdate = 0;
        }
      }

      await sink.close();

      // 添加到本地模型列表
      _localModels.add(LocalModel(
        id: model.id,
        info: model,
        path: targetPath,
        downloadedAt: DateTime.now(),
      ));

      // 保存本地模型列表
      await _saveLocalModels();

      logger.info('Model downloaded successfully: $targetPath');
    } catch (e) {
      // 清理失败的下载
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }

  /// 删除本地模型
  Future<void> deleteModel(String modelId) async {
    final index = _localModels.indexWhere((m) => m.id == modelId);
    if (index == -1) {
      throw ArgumentError('Model not found: $modelId');
    }

    final model = _localModels[index];
    final file = File(model.path);

    if (await file.exists()) {
      await file.delete();
    }

    _localModels.removeAt(index);
    await _saveLocalModels();

    logger.info('Model deleted: $modelId');
  }

  /// 检查模型是否已下载
  Future<bool> isModelDownloaded(String modelId) async {
    return _localModels.any((m) => m.id == modelId);
  }

  /// 获取模型路径
  Future<String?> getModelPath(String modelId) async {
    final model = _localModels.firstWhere(
      (m) => m.id == modelId,
      orElse: () => LocalModel(id: '', info: ModelInfo(id: '', name: '', type: ModelType.custom, format: '', size: 0), path: ''),
    );
    return model.path.isNotEmpty ? model.path : null;
  }

  /// 验证模型完整性
  Future<bool> verifyModel(String modelId) async {
    final model = _localModels.firstWhere(
      (m) => m.id == modelId,
      orElse: () => LocalModel(id: '', info: ModelInfo(id: '', name: '', type: ModelType.custom, format: '', size: 0), path: ''),
    );

    if (model.path.isEmpty) return false;

    final file = File(model.path);
    if (!await file.exists()) return false;

    final size = await file.length();
    return size == model.info.size;
  }

  /// 添加自定义模型
  Future<void> addCustomModel({
    required String path,
    required ModelType type,
    String? name,
    Map<String, dynamic>? metadata,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Model file not found', path);
    }

    final fileName = path.split('/').last;
    final format = fileName.split('.').last;

    final model = ModelInfo(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name ?? fileName,
      type: type,
      format: format,
      size: await file.length(),
      metadata: metadata,
    );

    _localModels.add(LocalModel(
      id: model.id,
      info: model,
      path: path,
      downloadedAt: DateTime.now(),
    ));

    await _saveLocalModels();
    logger.info('Custom model added: $path');
  }

  /// 加载本地模型列表
  Future<void> _loadLocalModels() async {
    final file = File('$_cacheDir/models.json');
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final json = jsonDecode(content);
        _localModels = (json['models'] as List<dynamic>?)
                ?.map((e) => LocalModel.fromJson(e))
                .toList() ??
            [];
      } catch (e) {
        logger.warning('Failed to load local models: $e');
      }
    }
  }

  /// 保存本地模型列表
  Future<void> _saveLocalModels() async {
    final file = File('$_cacheDir/models.json');
    final json = {
      'version': '1.0.0',
      'models': _localModels.map((m) => m.toJson()).toList(),
    };
    await file.writeAsString(jsonEncode(json));
  }
}
