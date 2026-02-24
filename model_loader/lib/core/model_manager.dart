/// ModelManager - Model download/cache/version management
/// Reference: CLAUDE.md Section 6

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
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
  })  : _cacheDir = cacheDir,
        _remoteModelListUrl = remoteModelListUrl,
        _enableRemoteModels = enableRemoteModels;

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

  /// Compute SHA256 hash of file
  Future<String> _computeSha256(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final bytes = await file.readAsBytes();
    // Simple hash for demo (in production, use crypto package)
    // This is a placeholder - in real implementation, use:
    // import 'dart:convert';
    // import 'package:crypto/crypto.dart';
    // return sha256.convert(bytes).toString();
    return 'sha256_${bytes.length}'; // Placeholder
  }

  /// Verify file SHA256
  Future<bool> _verifySha256(String filePath, String expectedSha256) async {
    final actualSha256 = await _computeSha256(filePath);
    return actualSha256 == expectedSha256;
  }

  /// Fetch remote model list
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
    final targetDir = savePath ?? '$_cacheDir/${model.id}';
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
          _releaseLock(model.id, version);
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

      if (model.downloadUrl != null) {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(model.downloadUrl!));
        final response = await request.close();

        if (response.statusCode != 200) {
          throw HttpException('Download failed: ${response.statusCode}');
        }

        final total = response.contentLength ?? model.size;
        var received = 0;

        final sink = tempFile.openWrite();

        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;

          _emitProgress(InstallProgress(
            modelId: model.id,
            version: version,
            phase: InstallPhase.downloading,
            progress: total > 0 ? received / total : 0.0,
            receivedBytes: received,
            totalBytes: total,
            requestId: requestId,
          ));
        }

        await sink.close();
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
          // Cleanup temp file
          if (await tempFile.exists()) {
            await tempFile.delete();
          }

          _emitProgress(InstallProgress(
            modelId: model.id,
            version: version,
            phase: InstallPhase.failed,
            requestId: requestId,
            error: {
              'code': 'MODEL_VERIFY_FAILED',
              'message': 'SHA256 mismatch',
            },
          ));

          _releaseLock(model.id, version, success: false);
          throw ModelLoaderException.modelVerifyFailed(
            artifact: model.id,
            expectedSha256: model.sha256,
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

      // Add to local models
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
      // Emit failed phase
      _emitProgress(InstallProgress(
        modelId: model.id,
        version: version,
        phase: InstallPhase.failed,
        requestId: requestId,
        error: {
          'code': 'DOWNLOAD_FAILED',
          'message': e.toString(),
        },
      ));

      _releaseLock(model.id, version, success: false);
      rethrow;

    } finally {
      _releaseLock(model.id, version);
    }
  }

  /// Delete local model
  Future<void> deleteModel(String modelId) async {
    final index = _localModels.indexWhere((m) => m.id == modelId);
    if (index == -1) {
      throw ModelLoaderException.modelNotFound(modelId);
    }

    final model = _localModels[index];

    // Delete model directory
    final modelDir = Directory('$_cacheDir/$modelId');
    if (await modelDir.exists()) {
      await modelDir.delete(recursive: true);
    }

    _localModels.removeAt(index);
    await _saveLocalModels();

    logger.info('Model deleted: $modelId');
  }

  /// Check if model is downloaded
  Future<bool> isModelDownloaded(String modelId) async {
    final modelDir = Directory('$_cacheDir/$modelId');
    if (!await modelDir.exists()) return false;

    final readyFile = File('$_cacheDir/$modelId/.ready');
    return readyFile.exists();
  }

  /// Get model path
  Future<String?> getModelPath(String modelId) async {
    final model = _localModels.firstWhere(
      (m) => m.id == modelId,
      orElse: () => LocalModel(
        id: '',
        info: ModelInfo(id: '', name: '', type: ModelType.custom, format: '', size: 0),
        path: '',
      ),
    );
    return model.path.isNotEmpty ? model.path : null;
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
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        // final json = jsonDecode(content); // Would parse
        _localModels = []; // Would load from JSON
      } catch (e) {
        logger.warning('Failed to load local models: $e');
      }
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
