/// Model Manifest Protocol
/// Reference: CLAUDE.md Section 3
library;

import 'model_type.dart';

/// Manifest schema version
const String kManifestSchemaVersion = '1.0.0';

/// Artifact role types
enum ArtifactRole {
  /// Model weights file
  model,

  /// Tokenizer file
  tokenizer,

  /// Model configuration
  config,

  /// Vocabulary file
  vocab,

  /// Adapter weights
  adapter,
}

extension ArtifactRoleExtension on ArtifactRole {
  String get name {
    switch (this) {
      case ArtifactRole.model:
        return 'model';
      case ArtifactRole.tokenizer:
        return 'tokenizer';
      case ArtifactRole.config:
        return 'config';
      case ArtifactRole.vocab:
        return 'vocab';
      case ArtifactRole.adapter:
        return 'adapter';
    }
  }

  static ArtifactRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'model':
        return ArtifactRole.model;
      case 'tokenizer':
        return ArtifactRole.tokenizer;
      case 'config':
        return ArtifactRole.config;
      case 'vocab':
        return ArtifactRole.vocab;
      case 'adapter':
        return ArtifactRole.adapter;
      default:
        return ArtifactRole.model;
    }
  }
}

/// Artifact file definition
class Artifact {
  /// Artifact name
  final String name;

  /// Role (model/tokenizer/config/vocab/adapter)
  final ArtifactRole role;

  /// File format (gguf, onnx, tflite, safetensors, spm, etc.)
  final String format;

  /// Relative path within model directory
  final String path;

  /// File size in bytes
  final int size;

  /// SHA256 hash for verification
  final String sha256;

  const Artifact({
    required this.name,
    required this.role,
    required this.format,
    required this.path,
    required this.size,
    required this.sha256,
  });

  factory Artifact.fromJson(Map<String, dynamic> json) {
    return Artifact(
      name: json['name'] ?? '',
      role: ArtifactRoleExtension.fromString(json['role'] ?? 'model'),
      format: json['format'] ?? '',
      path: json['path'] ?? '',
      size: json['size'] ?? 0,
      sha256: json['sha256'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'role': role.name,
      'format': format,
      'path': path,
      'size': size,
      'sha256': sha256,
    };
  }
}

/// Platform-specific SDK version requirements
class MinSdkVersion {
  /// Android minimum SDK version
  final int? android;

  /// iOS minimum version
  final String? ios;

  const MinSdkVersion({
    this.android,
    this.ios,
  });

  factory MinSdkVersion.fromJson(Map<String, dynamic> json) {
    return MinSdkVersion(
      android: json['android'],
      ios: json['ios'],
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (android != null) map['android'] = android;
    if (ios != null) map['ios'] = ios;
    return map;
  }
}

/// Backend version requirements
class MinBackendVersion {
  /// llama.cpp minimum version
  final String? llamaCpp;

  /// ONNX Runtime minimum version
  final String? onnxruntime;

  /// TensorFlow Lite minimum version
  final String? tflite;

  /// Vosk minimum version
  final String? vosk;

  const MinBackendVersion({
    this.llamaCpp,
    this.onnxruntime,
    this.tflite,
    this.vosk,
  });

  factory MinBackendVersion.fromJson(Map<String, dynamic> json) {
    return MinBackendVersion(
      llamaCpp: json['llama.cpp'],
      onnxruntime: json['onnxruntime'],
      tflite: json['tflite'],
      vosk: json['vosk'],
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (llamaCpp != null) map['llama.cpp'] = llamaCpp;
    if (onnxruntime != null) map['onnxruntime'] = onnxruntime;
    if (tflite != null) map['tflite'] = tflite;
    if (vosk != null) map['vosk'] = vosk;
    return map;
  }
}

/// Generation configuration defaults
class DefaultGenerationConfig {
  /// Sampling temperature
  final double? temperature;

  /// Top-P sampling
  final double? topP;

  /// Top-K sampling
  final int? topK;

  /// Repeat penalty
  final double? repeatPenalty;

  /// Maximum tokens to generate
  final int? maxTokens;

  const DefaultGenerationConfig({
    this.temperature,
    this.topP,
    this.topK,
    this.repeatPenalty,
    this.maxTokens,
  });

  factory DefaultGenerationConfig.fromJson(Map<String, dynamic> json) {
    return DefaultGenerationConfig(
      temperature: json['temperature']?.toDouble(),
      topP: json['topP']?.toDouble(),
      topK: json['topK'],
      repeatPenalty: json['repeatPenalty']?.toDouble(),
      maxTokens: json['maxTokens'],
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (temperature != null) map['temperature'] = temperature;
    if (topP != null) map['topP'] = topP;
    if (topK != null) map['topK'] = topK;
    if (repeatPenalty != null) map['repeatPenalty'] = repeatPenalty;
    if (maxTokens != null) map['maxTokens'] = maxTokens;
    return map;
  }
}

/// Special tokens configuration
class SpecialTokens {
  /// Beginning of sequence token
  final String? bos;

  /// End of sequence token
  final String? eos;

  /// Unknown token
  final String? unk;

  /// Padding token
  final String? pad;

  /// Additional special tokens
  final Map<String, String>? extra;

  const SpecialTokens({
    this.bos,
    this.eos,
    this.unk,
    this.pad,
    this.extra,
  });

  factory SpecialTokens.fromJson(Map<String, dynamic> json) {
    return SpecialTokens(
      bos: json['bos'],
      eos: json['eos'],
      unk: json['unk'],
      pad: json['pad'],
      extra: json['extra'] != null
          ? Map<String, String>.from(json['extra'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (bos != null) map['bos'] = bos;
    if (eos != null) map['eos'] = eos;
    if (unk != null) map['unk'] = unk;
    if (pad != null) map['pad'] = pad;
    if (extra != null) map['extra'] = extra;
    return map;
  }
}

/// Model definition in manifest
class ModelManifestItem {
  /// Model unique ID
  final String id;

  /// Model type
  final ModelType type;

  /// Model version
  final String version;

  /// Backend hints (preferred runtimes)
  final List<String> backendHints;

  /// Minimum SDK versions
  final MinSdkVersion? minSdkVersion;

  /// Minimum backend versions
  final MinBackendVersion? minBackendVersion;

  /// Quantization type (Q2_K, Q4_K_M, etc.)
  final String? quantization;

  /// Context length in tokens
  final int? contextLength;

  /// RoPE scaling type
  final String? ropeScaling;

  /// RoPE theta value
  final double? ropeTheta;

  /// Default generation config
  final DefaultGenerationConfig? defaultGenerationConfig;

  /// Chat template (chatml, llama2, etc.)
  final String? chatTemplate;

  /// Special tokens
  final SpecialTokens? specialTokens;

  /// Required artifacts
  final List<Artifact> requiredArtifacts;

  /// Optional artifacts
  final List<Artifact>? optionalArtifacts;

  /// Supported platforms
  final List<String> platforms;

  /// Additional metadata
  final Map<String, dynamic>? metadata;

  const ModelManifestItem({
    required this.id,
    required this.type,
    required this.version,
    this.backendHints = const [],
    this.minSdkVersion,
    this.minBackendVersion,
    this.quantization,
    this.contextLength,
    this.ropeScaling,
    this.ropeTheta,
    this.defaultGenerationConfig,
    this.chatTemplate,
    this.specialTokens,
    required this.requiredArtifacts,
    this.optionalArtifacts,
    this.platforms = const [],
    this.metadata,
  });

  factory ModelManifestItem.fromJson(Map<String, dynamic> json) {
    return ModelManifestItem(
      id: json['id'] ?? '',
      type: ModelTypeExtension.fromString(json['type'] ?? 'custom'),
      version: json['version'] ?? '1.0.0',
      backendHints: (json['backendHints'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      minSdkVersion: json['minSdkVersion'] != null
          ? MinSdkVersion.fromJson(json['minSdkVersion'])
          : null,
      minBackendVersion: json['minBackendVersion'] != null
          ? MinBackendVersion.fromJson(json['minBackendVersion'])
          : null,
      quantization: json['quantization'],
      contextLength: json['contextLength'],
      ropeScaling: json['ropeScaling'],
      ropeTheta: json['ropeTheta']?.toDouble(),
      defaultGenerationConfig: json['defaultGenerationConfig'] != null
          ? DefaultGenerationConfig.fromJson(json['defaultGenerationConfig'])
          : null,
      chatTemplate: json['chatTemplate'],
      specialTokens: json['specialTokens'] != null
          ? SpecialTokens.fromJson(json['specialTokens'])
          : null,
      requiredArtifacts: (json['requiredArtifacts'] as List<dynamic>?)
              ?.map((e) => Artifact.fromJson(e))
              .toList() ??
          [],
      optionalArtifacts: json['optionalArtifacts'] != null
          ? (json['optionalArtifacts'] as List<dynamic>)
              .map((e) => Artifact.fromJson(e))
              .toList()
          : null,
      platforms: (json['platforms'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'version': version,
      'backendHints': backendHints,
      'minSdkVersion': minSdkVersion?.toJson(),
      'minBackendVersion': minBackendVersion?.toJson(),
      'quantization': quantization,
      'contextLength': contextLength,
      'ropeScaling': ropeScaling,
      'ropeTheta': ropeTheta,
      'defaultGenerationConfig': defaultGenerationConfig?.toJson(),
      'chatTemplate': chatTemplate,
      'specialTokens': specialTokens?.toJson(),
      'requiredArtifacts': requiredArtifacts.map((e) => e.toJson()).toList(),
      'optionalArtifacts': optionalArtifacts?.map((e) => e.toJson()).toList(),
      'platforms': platforms,
      'metadata': metadata,
    };
  }
}

/// Model manifest root
class ModelManifest {
  /// Manifest schema version
  final String manifestSchemaVersion;

  /// Manifest content version
  final String manifestVersion;

  /// Generation timestamp (UTC)
  final String generatedAt;

  /// Model list
  final List<ModelManifestItem> models;

  const ModelManifest({
    required this.manifestSchemaVersion,
    required this.manifestVersion,
    required this.generatedAt,
    required this.models,
  });

  factory ModelManifest.fromJson(Map<String, dynamic> json) {
    return ModelManifest(
      manifestSchemaVersion:
          json['manifestSchemaVersion'] ?? kManifestSchemaVersion,
      manifestVersion: json['manifestVersion'] ?? '',
      generatedAt: json['generatedAt'] ?? DateTime.now().toUtc().toIso8601String(),
      models: (json['models'] as List<dynamic>?)
              ?.map((e) => ModelManifestItem.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'manifestSchemaVersion': manifestSchemaVersion,
      'manifestVersion': manifestVersion,
      'generatedAt': generatedAt,
      'models': models.map((e) => e.toJson()).toList(),
    };
  }

  /// Create manifest from JSON string
  factory ModelManifest.parse(String jsonString) {
    // import 'dart:convert';
    // return ModelManifest.fromJson(jsonDecode(jsonString));
    // Using dynamic import workaround
    return ModelManifest._parseDynamic(jsonString);
  }

  factory ModelManifest._parseDynamic(String jsonString) {
    // Simple JSON parsing without import
    throw UnimplementedError('Use ModelManifest.fromJson with parsed JSON');
  }

  /// Create empty manifest
  factory ModelManifest.empty() {
    return ModelManifest(
      manifestSchemaVersion: kManifestSchemaVersion,
      manifestVersion: '',
      generatedAt: DateTime.now().toUtc().toIso8601String(),
      models: [],
    );
  }

  /// Get model by ID
  ModelManifestItem? getModel(String id) {
    try {
      return models.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get models by type
  List<ModelManifestItem> getModelsByType(ModelType type) {
    return models.where((m) => m.type == type).toList();
  }

  /// Filter models by platform
  List<ModelManifestItem> getModelsForPlatform(String platform) {
    return models
        .where((m) => m.platforms.isEmpty || m.platforms.contains(platform))
        .toList();
  }
}
