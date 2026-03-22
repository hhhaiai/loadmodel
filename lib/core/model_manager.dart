// ModelManager - Model download/cache/version management
// Reference: CLAUDE.md Section 6

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../models/model_info.dart';
import '../models/model_type.dart';
import '../models/download_task.dart';
import '../models/model_loader_exception.dart';
import '../utils/logger.dart';
import 'platform_utils.dart';

/// Concurrent download lock entry
class DownloadLock {
  final String modelId;
  final String version;
  final Completer<void> completer = Completer<void>();
  DateTime createdAt = DateTime.now();

  DownloadLock({required this.modelId, required this.version});
}

/// ModelManager - Model download/cache/version management
class ModelManager {
  final String _cacheDir;
  final String? _remoteModelListUrl;
  final bool _enableRemoteModels;
  final Duration _downloadConnectTimeout;
  final Duration _downloadReadTimeout;
  final int _fallbackMaxDownloadBytes;

  List<ModelInfo> _remoteModels = [];
  List<LocalModel> _localModels = [];

  /// Active download locks (modelId -> DownloadLock)
  final Map<String, DownloadLock> _downloadLocks = {};

  /// Stream controller for install progress events
  final _installProgressController = StreamController<InstallProgress>.broadcast();

  /// Get install progress stream
  Stream<InstallProgress> get installProgressStream => _installProgressController.stream;

  ModelManager({
    required String cacheDir,
    String? remoteModelListUrl,
    bool enableRemoteModels = true,
    Duration downloadConnectTimeout = const Duration(seconds: 20),
    Duration downloadReadTimeout = const Duration(minutes: 5),
    int fallbackMaxDownloadBytes = 2 * 1024 * 1024 * 1024,
  })  : _cacheDir = cacheDir,
        _remoteModelListUrl = remoteModelListUrl,
        _enableRemoteModels = enableRemoteModels,
        _downloadConnectTimeout = downloadConnectTimeout,
        _downloadReadTimeout = downloadReadTimeout,
        _fallbackMaxDownloadBytes = fallbackMaxDownloadBytes;

  /// Initialize
  Future<void> init() async {
    try {
      final dir = Directory(_cacheDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      logger.warning('Cannot create cache directory: $e');
    }

    await _loadLocalModels();

    logger.info('ModelManager initialized. Local models: ${_localModels.length}');
  }

  /// Dispose resources
  void dispose() {
    _installProgressController.close();
  }

  /// Emit install progress event
  void _emitProgress(InstallProgress progress) {
    _installProgressController.add(progress);
  }

  /// Generate request ID
  String _generateRequestId() {
    return 'install_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  /// Acquire download lock (per CLAUDE.md Section 6.2)
  Future<DownloadLock?> _acquireLock(String modelId, String version) async {
    final key = '$modelId:$version';

    // Check if lock already exists
    if (_downloadLocks.containsKey(key)) {
      // Wait for existing download to complete
      await _downloadLocks[key]!.completer.future;
      return null; // Download already completed or failed
    }

    // Create new lock
    final lock = DownloadLock(modelId: modelId, version: version);
    // Avoid unhandled completer errors when no waiter is attached.
    lock.completer.future.catchError((_) {});
    _downloadLocks[key] = lock;
    return lock;
  }

  /// Release download lock
  void _releaseLock(String modelId, String version, {bool success = true}) {
    final key = '$modelId:$version';
    final lock = _downloadLocks.remove(key);
    if (lock != null && !lock.completer.isCompleted) {
      if (success) {
        lock.completer.complete();
      } else {
        lock.completer.completeError(Exception('Download failed'));
      }
    }
  }

  String _normalizeSha256(String hash) {
    final normalized = hash.trim().toLowerCase();
    if (normalized.startsWith('sha256:')) {
      return normalized.substring('sha256:'.length);
    }
    return normalized;
  }

  String _versionDir(String modelId, String version) {
    return '$_cacheDir/$modelId/$version';
  }

  /// Compute SHA256 hash of file
  Future<String> _computeSha256(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  /// Verify file SHA256
  Future<bool> _verifySha256(String filePath, String expectedSha256) async {
    final actualSha256 = await _computeSha256(filePath);
    return _normalizeSha256(actualSha256) == _normalizeSha256(expectedSha256);
  }

  /// Fetch remote model list
  Future<List<ModelInfo>> fetchRemoteModels() async {
    if (!_enableRemoteModels || _remoteModelListUrl == null) {
      return [];
    }

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(_remoteModelListUrl));
      final response = await request.close();

      if (response.statusCode == 200) {
        // final content = await response.transform(utf8.decoder).join();
        // final json = jsonDecode(content); // Would need dart:convert

        _remoteModels = []; // Would parse from JSON

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

  /// Get local downloaded models
  Future<List<LocalModel>> getLocalModels() async {
    return _localModels;
  }

  /// Get cached remote model list
  List<ModelInfo> get remoteModels => _remoteModels;

  /// Install model (download + verify + extract)
  /// Reference: CLAUDE.md Section 6
  Stream<InstallProgress> installModel(
    ModelInfo model, {
    String? savePath,
  }) async* {
    final requestId = _generateRequestId();
    final version = model.version;
    final targetDir = savePath ?? _versionDir(model.id, version);
    final modelDir = Directory(targetDir);

    // Emit idle phase
    _emitProgress(InstallProgress(
      modelId: model.id,
      version: version,
      phase: InstallPhase.idle,
      requestId: requestId,
    ));

    // Try to acquire lock
    final lock = await _acquireLock(model.id, version);
    if (lock == null) {
      // Another download is in progress, wait for it
      return;
    }

    var verifyFailed = false;
    var sizeExceeded = false;

    try {
      // Check if already installed
      if (await modelDir.exists()) {
        final readyFile = File('$targetDir/.ready');
        if (await readyFile.exists()) {
          _emitProgress(InstallProgress(
            modelId: model.id,
            version: version,
            phase: InstallPhase.ready,
            progress: 1.0,
            totalBytes: model.size,
            requestId: requestId,
          ));
          return;
        }
      }

      // Emit downloading phase
      _emitProgress(InstallProgress(
        modelId: model.id,
        version: version,
        phase: InstallPhase.downloading,
        progress: 0.0,
        totalBytes: model.size,
        requestId: requestId,
      ));

      // Download to temp file
      final tempPath = '$targetDir.tmp_${DateTime.now().millisecondsSinceEpoch}';
      final tempFile = File(tempPath);

      if (savePath == null) {
        if (!targetDir.startsWith('$_cacheDir/')) {
          throw ArgumentError('Invalid install directory: $targetDir');
        }
      }

      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }

      if (model.downloadUrl != null) {
        final client = HttpClient();
        client.connectionTimeout = _downloadConnectTimeout;

        try {
          final request = await client.getUrl(Uri.parse(model.downloadUrl!));
          final response = await request.close().timeout(_downloadReadTimeout);

          if (response.statusCode != 200) {
            throw HttpException('Download failed: ${response.statusCode}');
          }

          final contentLength = response.contentLength;
          final expectedSize = model.size > 0 ? model.size : _fallbackMaxDownloadBytes;
          final resolvedTotal = contentLength > 0 ? contentLength : expectedSize;
          final maxAllowedSize = expectedSize > 0 ? expectedSize : _fallbackMaxDownloadBytes;

          if (contentLength > 0 && contentLength > maxAllowedSize) {
            throw StateError(
              'DOWNLOAD_SIZE_EXCEEDED: content-length $contentLength > max $maxAllowedSize',
            );
          }

          var received = 0;

          final sink = tempFile.openWrite();
          try {
            await for (final chunk in response.timeout(_downloadReadTimeout)) {
              sink.add(chunk);
              received += chunk.length;

              if (received > maxAllowedSize) {
                throw StateError(
                  'DOWNLOAD_SIZE_EXCEEDED: received $received > max $maxAllowedSize',
                );
              }

              _emitProgress(InstallProgress(
                modelId: model.id,
                version: version,
                phase: InstallPhase.downloading,
                progress: resolvedTotal > 0 ? received / resolvedTotal : 0.0,
                receivedBytes: received,
                totalBytes: resolvedTotal,
                requestId: requestId,
              ));
            }
          } finally {
            await sink.close();
          }
        } finally {
          client.close(force: true);
        }
      }

      // Emit verifying phase
      _emitProgress(InstallProgress(
        modelId: model.id,
        version: version,
        phase: InstallPhase.verifying,
        progress: 1.0,
        requestId: requestId,
      ));

      // Verify SHA256 if provided
      if (model.sha256 != null && model.sha256!.isNotEmpty) {
        final isValid = await _verifySha256(tempPath, model.sha256!);

        if (!isValid) {
          final actualSha256 = await _computeSha256(tempPath);
          final normalizedActual = _normalizeSha256(actualSha256);
          final normalizedExpected = _normalizeSha256(model.sha256!);
          verifyFailed = true;

          // Cleanup temp file
          if (await tempFile.exists()) {
            await tempFile.delete();
          }

          throw ModelLoaderException.modelVerifyFailed(
            artifact: model.id,
            expectedSha256: normalizedExpected,
            actualSha256: normalizedActual,
          );
        }
      }

      // Create model directory
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }

      // Atomic rename (per CLAUDE.md Section 6.1)
      final targetPath = '$targetDir/${model.id}.${model.format}';
      await tempFile.rename(targetPath);

      // Mark as ready
      final readyFile = File('$targetDir/.ready');
      await readyFile.writeAsString(DateTime.now().toIso8601String());

      // Upsert local models (id + version)
      _localModels = _localModels
          .where((m) => !(m.id == model.id && m.info.version == version))
          .toList();
      _localModels.add(LocalModel(
        id: model.id,
        info: model,
        path: targetPath,
        downloadedAt: DateTime.now(),
      ));

      await _saveLocalModels();

      // Emit ready phase
      _emitProgress(InstallProgress(
        modelId: model.id,
        version: version,
        phase: InstallPhase.ready,
        progress: 1.0,
        totalBytes: model.size,
        requestId: requestId,
      ));

      logger.info('Model installed successfully: $targetPath');

    } catch (e) {
      if (e is StateError && e.message.startsWith('DOWNLOAD_SIZE_EXCEEDED')) {
        sizeExceeded = true;
      }

      // Emit failed phase
      _emitProgress(InstallProgress(
        modelId: model.id,
        version: version,
        phase: InstallPhase.failed,
        requestId: requestId,
        error: {
          'code': verifyFailed
              ? 'MODEL_VERIFY_FAILED'
              : sizeExceeded
                  ? 'DOWNLOAD_SIZE_EXCEEDED'
                  : 'DOWNLOAD_FAILED',
          'message': e.toString(),
        },
      ));

      _releaseLock(model.id, version, success: false);
      rethrow;

    } finally {
      _releaseLock(model.id, version, success: !(verifyFailed || sizeExceeded));
    }
  }

  /// Delete local model
  Future<void> deleteModel(String modelId, {String? version}) async {
    LocalModel? model;

    if (version != null) {
      for (final item in _localModels) {
        if (item.id == modelId && item.info.version == version) {
          model = item;
          break;
        }
      }
    } else {
      for (var i = _localModels.length - 1; i >= 0; i--) {
        if (_localModels[i].id == modelId) {
          model = _localModels[i];
          break;
        }
      }
    }

    if (model == null) {
      throw ModelLoaderException.modelNotFound(modelId);
    }

    final modelVersion = version ?? model.info.version;

    if (modelVersion.contains('..') || modelId.contains('..')) {
      throw ArgumentError('Invalid model identifier');
    }

    // Delete version directory
    final modelDir = Directory(_versionDir(modelId, modelVersion));
    if (await modelDir.exists()) {
      await modelDir.delete(recursive: true);
    }

    _localModels = _localModels
        .where((m) => !(m.id == modelId && m.info.version == modelVersion))
        .toList();
    await _saveLocalModels();

    logger.info('Model deleted: $modelId@$modelVersion');
  }

  /// Check if model is downloaded
  Future<bool> isModelDownloaded(String modelId, {String? version}) async {
    if (version != null) {
      final modelDir = Directory(_versionDir(modelId, version));
      if (!await modelDir.exists()) return false;
      final readyFile = File('${_versionDir(modelId, version)}/.ready');
      return readyFile.exists();
    }

    final modelRootDir = Directory('$_cacheDir/$modelId');
    if (!await modelRootDir.exists()) return false;

    final versionDirs = await modelRootDir
        .list()
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList();

    for (final dir in versionDirs) {
      final readyFile = File('${dir.path}/.ready');
      if (await readyFile.exists()) {
        return true;
      }
    }

    return false;
  }

  /// Get model path
  Future<String?> getModelPath(String modelId, {String? version}) async {
    LocalModel? model;

    if (version != null) {
      for (final item in _localModels) {
        if (item.id == modelId && item.info.version == version) {
          model = item;
          break;
        }
      }
    } else {
      for (var i = _localModels.length - 1; i >= 0; i--) {
        if (_localModels[i].id == modelId) {
          model = _localModels[i];
          break;
        }
      }
    }

    return model?.path;
  }

  /// Verify model integrity
  Future<bool> verifyModel(String modelId) async {
    final model = _localModels.firstWhere(
      (m) => m.id == modelId,
      orElse: () => LocalModel(
        id: '',
        info: ModelInfo(id: '', name: '', type: ModelType.custom, format: '', size: 0),
        path: '',
      ),
    );

    if (model.path.isEmpty) return false;

    final file = File(model.path);
    if (!await file.exists()) return false;

    final size = await file.length();
    return size == model.info.size;
  }

  /// Add custom model
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

  /// Load local model list
  Future<void> _loadLocalModels() async {
    final file = File('$_cacheDir/models.json');
    _localModels = [];

    if (!await file.exists()) {
      return;
    }

    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content);

      if (decoded is! Map<String, dynamic>) {
        logger.warning('Invalid models.json format: root is not object');
        return;
      }

      final models = decoded['models'];
      if (models is! List) {
        logger.warning('Invalid models.json format: models is not list');
        return;
      }

      _localModels = models
          .whereType<Map>()
          .map((item) => LocalModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      logger.warning('Failed to load local models: $e');
      _localModels = [];
    }
  }

  /// Save local model list
  Future<void> _saveLocalModels() async {
    final file = File('$_cacheDir/models.json');
    final json = {
      'version': '1.0.0',
      'models': _localModels.map((m) => m.toJson()).toList(),
    };
    await file.writeAsString(jsonEncode(json));
  }
}
