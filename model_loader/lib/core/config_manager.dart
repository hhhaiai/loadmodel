import 'dart:convert';
import 'dart:io';
import 'platform_utils.dart';
import '../utils/logger.dart';

/// 量化级别
enum QuantizationLevel {
  q2_K,
  q3_K_S,
  q3_K_M,
  q4_0,
  q4_K_S,
  q4_K_M,
  q5_0,
  q5_1,
  q8_0,
  f16,
  f32,
}

extension QuantizationLevelExtension on QuantizationLevel {
  String get displayName {
    switch (this) {
      case QuantizationLevel.q2_K:
        return 'Q2_K (2.5-bit)';
      case QuantizationLevel.q3_K_S:
        return 'Q3_K_S';
      case QuantizationLevel.q3_K_M:
        return 'Q3_K_M';
      case QuantizationLevel.q4_0:
        return 'Q4_0';
      case QuantizationLevel.q4_K_S:
        return 'Q4_K_S';
      case QuantizationLevel.q4_K_M:
        return 'Q4_K_M';
      case QuantizationLevel.q5_0:
        return 'Q5_0';
      case QuantizationLevel.q5_1:
        return 'Q5_1';
      case QuantizationLevel.q8_0:
        return 'Q8_0';
      case QuantizationLevel.f16:
        return 'FP16';
      case QuantizationLevel.f32:
        return 'FP32';
    }
  }

  /// 获取比特数
  int get bits {
    switch (this) {
      case QuantizationLevel.q2_K:
        return 2;
      case QuantizationLevel.q3_K_S:
      case QuantizationLevel.q3_K_M:
        return 3;
      case QuantizationLevel.q4_0:
      case QuantizationLevel.q4_K_S:
      case QuantizationLevel.q4_K_M:
        return 4;
      case QuantizationLevel.q5_0:
      case QuantizationLevel.q5_1:
        return 5;
      case QuantizationLevel.q8_0:
        return 8;
      case QuantizationLevel.f16:
        return 16;
      case QuantizationLevel.f32:
        return 32;
    }
  }
}

/// 量化配置
class QuantizationConfig {
  final QuantizationLevel level;
  final int threads;
  final bool enableGPU;
  final int gpuLayers;

  const QuantizationConfig({
    this.level = QuantizationLevel.q4_K_M,
    this.threads = 4,
    this.enableGPU = true,
    this.gpuLayers = 32,
  });

  Map<String, dynamic> toJson() {
    return {
      'level': level.name,
      'threads': threads,
      'enableGPU': enableGPU,
      'gpuLayers': gpuLayers,
    };
  }

  factory QuantizationConfig.fromJson(Map<String, dynamic> json) {
    return QuantizationConfig(
      level: QuantizationLevel.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => QuantizationLevel.q4_K_M,
      ),
      threads: json['threads'] ?? 4,
      enableGPU: json['enableGPU'] ?? true,
      gpuLayers: json['gpuLayers'] ?? 32,
    );
  }
}

/// ConfigManager - 配置管理
class ConfigManager {
  String? _customModelPath;
  String? _modelCacheDir;
  String? _remoteModelListUrl;
  QuantizationConfig? _quantizationConfig;

  final String _configDir;

  ConfigManager({String? configDir})
      : _configDir = configDir ?? PlatformUtils.getDefaultCacheDirSync();

  /// 初始化
  Future<void> init() async {
    await loadConfig();
  }

  /// 获取/设置自定义模型路径
  String? get customModelPath => _customModelPath;
  Future<void> setCustomModelPath(String path) async {
    _customModelPath = path;
    await saveConfig();
  }

  /// 获取/设置模型缓存目录
  String get modelCacheDir => _modelCacheDir ?? PlatformUtils.getDefaultCacheDirSync();
  Future<void> setModelCacheDir(String path) async {
    _modelCacheDir = path;
    await saveConfig();
  }

  /// 获取/设置远程模型列表地址
  String? get remoteModelListUrl => _remoteModelListUrl;
  Future<void> setRemoteModelListUrl(String url) async {
    _remoteModelListUrl = url;
    await saveConfig();
  }

  /// 获取/设置量化配置 (仅桌面端)
  QuantizationConfig? get quantizationConfig => _quantizationConfig;
  Future<void> setQuantizationConfig(QuantizationConfig config) async {
    _quantizationConfig = config;
    await saveConfig();
  }

  /// 保存配置到本地
  Future<void> saveConfig() async {
    try {
      final dir = Directory(_configDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File('$_configDir/config.json');
      final json = {
        'customModelPath': _customModelPath,
        'modelCacheDir': _modelCacheDir,
        'remoteModelListUrl': _remoteModelListUrl,
        'quantizationConfig': _quantizationConfig?.toJson(),
      };
      await file.writeAsString(jsonEncode(json));
      logger.info('Config saved');
    } catch (e, st) {
      logger.error('Failed to save config', e, st);
    }
  }

  /// 从本地加载配置
  Future<void> loadConfig() async {
    try {
      final file = File('$_configDir/config.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content);

        _customModelPath = json['customModelPath'];
        _modelCacheDir = json['modelCacheDir'];
        _remoteModelListUrl = json['remoteModelListUrl'];
        if (json['quantizationConfig'] != null) {
          _quantizationConfig = QuantizationConfig.fromJson(
            json['quantizationConfig'],
          );
        }
        logger.info('Config loaded');
      }
    } catch (e, st) {
      logger.error('Failed to load config', e, st);
    }
  }
}
