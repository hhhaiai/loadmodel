import 'model_type.dart';

/// 平台要求
class PlatformRequirements {
  /// 最低内存要求 (MB)
  final int minMemoryMB;

  /// 是否需要GPU
  final bool supportsGpu;

  /// 支持的平台
  final List<String> supportedPlatforms;

  const PlatformRequirements({
    required this.minMemoryMB,
    this.supportsGpu = false,
    this.supportedPlatforms = const ['ios', 'android', 'macos', 'windows', 'linux'],
  });

  factory PlatformRequirements.fromJson(Map<String, dynamic> json) {
    return PlatformRequirements(
      minMemoryMB: json['minMemory'] ?? json['minMemoryMB'] ?? 0,
      supportsGpu: json['supportsGpu'] ?? false,
      supportedPlatforms: (json['platforms'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['ios', 'android', 'macos', 'windows', 'linux'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'minMemoryMB': minMemoryMB,
      'supportsGpu': supportsGpu,
      'platforms': supportedPlatforms,
    };
  }
}

/// 模型信息
class ModelInfo {
  /// 模型唯一标识
  final String id;

  /// 模型显示名称
  final String name;

  /// 模型类型
  final ModelType type;

  /// 模型格式 (onnx, gguf, safetensors, tflite)
  final String format;

  /// 模型版本
  final String version;

  /// 文件大小 (bytes)
  final int size;

  /// 下载地址
  final String? downloadUrl;

  /// SHA256 校验值
  final String? sha256;

  /// 额外元数据
  final Map<String, dynamic>? metadata;

  /// 推荐量化等级
  final List<String>? recommendedQuantizations;

  /// 平台要求
  final PlatformRequirements? platformReq;

  /// 模型描述
  final String? description;

  const ModelInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.format,
    this.version = '1.0.0',
    required this.size,
    this.downloadUrl,
    this.sha256,
    this.metadata,
    this.recommendedQuantizations,
    this.platformReq,
    this.description,
  });

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: ModelTypeExtension.fromString(json['type'] ?? 'custom'),
      format: json['format'] ?? '',
      version: json['version'] ?? '1.0.0',
      size: json['size'] ?? 0,
      downloadUrl: json['downloadUrl'],
      sha256: json['sha256'],
      metadata: json['metadata'],
      recommendedQuantizations:
          (json['recommendedQuantizations'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
      platformReq: json['platforms'] != null || json['minMemory'] != null
          ? PlatformRequirements.fromJson(json)
          : null,
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'format': format,
      'version': version,
      'size': size,
      'downloadUrl': downloadUrl,
      'sha256': sha256,
      'metadata': metadata,
      'recommendedQuantizations': recommendedQuantizations,
      ...?platformReq?.toJson(),
      'description': description,
    };
  }

  /// 格式化文件大小
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// 本地模型
class LocalModel {
  /// 模型ID
  final String id;

  /// 模型信息
  final ModelInfo info;

  /// 本地路径
  final String path;

  /// 下载时间
  final DateTime? downloadedAt;

  /// 最后使用时间
  final DateTime? lastUsedAt;

  const LocalModel({
    required this.id,
    required this.info,
    required this.path,
    this.downloadedAt,
    this.lastUsedAt,
  });

  factory LocalModel.fromJson(Map<String, dynamic> json) {
    return LocalModel(
      id: json['id'] ?? '',
      info: ModelInfo.fromJson(json['info'] ?? {}),
      path: json['path'] ?? '',
      downloadedAt: json['downloadedAt'] != null
          ? DateTime.parse(json['downloadedAt'])
          : null,
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.parse(json['lastUsedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'info': info.toJson(),
      'path': path,
      'downloadedAt': downloadedAt?.toIso8601String(),
      'lastUsedAt': lastUsedAt?.toIso8601String(),
    };
  }
}
