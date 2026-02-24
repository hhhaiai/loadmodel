/// ModelLoader Error Codes
/// Reference: CLAUDE.md Section 8

/// Standard error codes
enum ModelLoaderErrorCode {
  /// Model not found in registry or cache
  MODEL_NOT_FOUND,

  /// Model file verification failed (sha256 mismatch)
  MODEL_VERIFY_FAILED,

  /// Requested runtime is not available
  RUNTIME_NOT_AVAILABLE,

  /// Platform not supported
  UNSUPPORTED_PLATFORM,

  /// Insufficient memory to run model
  INSUFFICIENT_MEMORY,

  /// Task execution timeout
  TASK_TIMEOUT,

  /// Task was cancelled
  TASK_CANCELLED,

  /// Download failed
  DOWNLOAD_FAILED,

  /// Invalid model format
  INVALID_MODEL_FORMAT,

  /// Model loading failed
  MODEL_LOAD_FAILED,

  /// Inference failed
  INFERENCE_FAILED,

  /// Configuration error
  CONFIG_ERROR,

  /// Unknown error
  UNKNOWN,
}

extension ModelLoaderErrorCodeExtension on ModelLoaderErrorCode {
  String get code {
    switch (this) {
      case ModelLoaderErrorCode.MODEL_NOT_FOUND:
        return 'MODEL_NOT_FOUND';
      case ModelLoaderErrorCode.MODEL_VERIFY_FAILED:
        return 'MODEL_VERIFY_FAILED';
      case ModelLoaderErrorCode.RUNTIME_NOT_AVAILABLE:
        return 'RUNTIME_NOT_AVAILABLE';
      case ModelLoaderErrorCode.UNSUPPORTED_PLATFORM:
        return 'UNSUPPORTED_PLATFORM';
      case ModelLoaderErrorCode.INSUFFICIENT_MEMORY:
        return 'INSUFFICIENT_MEMORY';
      case ModelLoaderErrorCode.TASK_TIMEOUT:
        return 'TASK_TIMEOUT';
      case ModelLoaderErrorCode.TASK_CANCELLED:
        return 'TASK_CANCELLED';
      case ModelLoaderErrorCode.DOWNLOAD_FAILED:
        return 'DOWNLOAD_FAILED';
      case ModelLoaderErrorCode.INVALID_MODEL_FORMAT:
        return 'INVALID_MODEL_FORMAT';
      case ModelLoaderErrorCode.MODEL_LOAD_FAILED:
        return 'MODEL_LOAD_FAILED';
      case ModelLoaderErrorCode.INFERENCE_FAILED:
        return 'INFERENCE_FAILED';
      case ModelLoaderErrorCode.CONFIG_ERROR:
        return 'CONFIG_ERROR';
      case ModelLoaderErrorCode.UNKNOWN:
        return 'UNKNOWN';
    }
  }

  String get defaultMessage {
    switch (this) {
      case ModelLoaderErrorCode.MODEL_NOT_FOUND:
        return 'Model not found';
      case ModelLoaderErrorCode.MODEL_VERIFY_FAILED:
        return 'Model verification failed';
      case ModelLoaderErrorCode.RUNTIME_NOT_AVAILABLE:
        return 'Runtime not available';
      case ModelLoaderErrorCode.UNSUPPORTED_PLATFORM:
        return 'Platform not supported';
      case ModelLoaderErrorCode.INSUFFICIENT_MEMORY:
        return 'Insufficient memory';
      case ModelLoaderErrorCode.TASK_TIMEOUT:
        return 'Task timeout';
      case ModelLoaderErrorCode.TASK_CANCELLED:
        return 'Task cancelled';
      case ModelLoaderErrorCode.DOWNLOAD_FAILED:
        return 'Download failed';
      case ModelLoaderErrorCode.INVALID_MODEL_FORMAT:
        return 'Invalid model format';
      case ModelLoaderErrorCode.MODEL_LOAD_FAILED:
        return 'Model loading failed';
      case ModelLoaderErrorCode.INFERENCE_FAILED:
        return 'Inference failed';
      case ModelLoaderErrorCode.CONFIG_ERROR:
        return 'Configuration error';
      case ModelLoaderErrorCode.UNKNOWN:
        return 'Unknown error';
    }
  }

  bool get isRetriable {
    switch (this) {
      case ModelLoaderErrorCode.MODEL_NOT_FOUND:
      case ModelLoaderErrorCode.UNSUPPORTED_PLATFORM:
      case ModelLoaderErrorCode.INVALID_MODEL_FORMAT:
      case ModelLoaderErrorCode.CONFIG_ERROR:
        return false;
      case ModelLoaderErrorCode.MODEL_VERIFY_FAILED:
      case ModelLoaderErrorCode.RUNTIME_NOT_AVAILABLE:
      case ModelLoaderErrorCode.INSUFFICIENT_MEMORY:
      case ModelLoaderErrorCode.TASK_TIMEOUT:
      case ModelLoaderErrorCode.TASK_CANCELLED:
      case ModelLoaderErrorCode.DOWNLOAD_FAILED:
      case ModelLoaderErrorCode.MODEL_LOAD_FAILED:
      case ModelLoaderErrorCode.INFERENCE_FAILED:
      case ModelLoaderErrorCode.UNKNOWN:
        return true;
    }
  }
}

/// Error details structure
class ModelLoaderErrorDetails {
  /// Backend type (e.g., 'onnxruntime', 'llama.cpp')
  final String? backend;

  /// Artifact name that caused the error
  final String? artifact;

  /// Expected sha256 hash
  final String? expectedSha256;

  /// Actual sha256 hash
  final String? actualSha256;

  /// Required memory in MB
  final int? requiredMemoryMB;

  /// Available memory in MB
  final int? availableMemoryMB;

  /// Model ID
  final String? modelId;

  /// Additional details
  final Map<String, dynamic>? extra;

  const ModelLoaderErrorDetails({
    this.backend,
    this.artifact,
    this.expectedSha256,
    this.actualSha256,
    this.requiredMemoryMB,
    this.availableMemoryMB,
    this.modelId,
    this.extra,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (backend != null) map['backend'] = backend;
    if (artifact != null) map['artifact'] = artifact;
    if (expectedSha256 != null) map['expectedSha256'] = expectedSha256;
    if (actualSha256 != null) map['actualSha256'] = actualSha256;
    if (requiredMemoryMB != null) map['requiredMemoryMB'] = requiredMemoryMB;
    if (availableMemoryMB != null) map['availableMemoryMB'] = availableMemoryMB;
    if (modelId != null) map['modelId'] = modelId;
    if (extra != null) map.addAll(extra!);
    return map;
  }

  factory ModelLoaderErrorDetails.fromJson(Map<String, dynamic> json) {
    return ModelLoaderErrorDetails(
      backend: json['backend'],
      artifact: json['artifact'],
      expectedSha256: json['expectedSha256'],
      actualSha256: json['actualSha256'],
      requiredMemoryMB: json['requiredMemoryMB'],
      availableMemoryMB: json['availableMemoryMB'],
      modelId: json['modelId'],
      extra: json['extra'],
    );
  }
}

/// Structured error information
class ModelLoaderException implements Exception {
  /// Error code
  final ModelLoaderErrorCode code;

  /// Error message
  final String message;

  /// Whether the error is retriable
  final bool retriable;

  /// Detailed error information
  final ModelLoaderErrorDetails? details;

  /// Suggestion for recovery
  final String? suggestion;

  /// Original exception
  final Object? originalError;

  const ModelLoaderException({
    required this.code,
    String? message,
    this.retriable = false,
    this.details,
    this.suggestion,
    this.originalError,
  }) : message = message ?? '';

  String get displayMessage => message.isNotEmpty ? message : code.defaultMessage;

  factory ModelLoaderException.fromJson(Map<String, dynamic> json) {
    return ModelLoaderException(
      code: ModelLoaderErrorCode.values.firstWhere(
        (e) => e.code == json['code'],
        orElse: () => ModelLoaderErrorCode.UNKNOWN,
      ),
      message: json['message'] ?? '',
      retriable: json['retriable'] ?? false,
      details: json['details'] != null
          ? ModelLoaderErrorDetails.fromJson(json['details'])
          : null,
      suggestion: json['suggestion'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code.code,
      'message': displayMessage,
      'retriable': retriable,
      'details': details?.toJson(),
      'suggestion': suggestion,
    };
  }

  @override
  String toString() => 'ModelLoaderException: ${code.code} - $displayMessage';

  /// Factory constructors for common errors
  factory ModelLoaderException.modelNotFound(String modelId) {
    return ModelLoaderException(
      code: ModelLoaderErrorCode.MODEL_NOT_FOUND,
      message: 'Model not found: $modelId',
      retriable: false,
      details: ModelLoaderErrorDetails(modelId: modelId),
      suggestion: 'Check model ID or download the model first',
    );
  }

  factory ModelLoaderException.modelVerifyFailed({
    required String artifact,
    String? expectedSha256,
    String? actualSha256,
  }) {
    return ModelLoaderException(
      code: ModelLoaderErrorCode.MODEL_VERIFY_FAILED,
      message: 'Model file sha256 mismatch: $artifact',
      retriable: true,
      details: ModelLoaderErrorDetails(
        artifact: artifact,
        expectedSha256: expectedSha256,
        actualSha256: actualSha256,
      ),
      suggestion: 'Re-download the model',
    );
  }

  factory ModelLoaderException.runtimeNotAvailable({
    required String backend,
    String? reason,
  }) {
    return ModelLoaderException(
      code: ModelLoaderErrorCode.RUNTIME_NOT_AVAILABLE,
      message: 'Runtime not available: $backend${reason != null ? ' - $reason' : ''}',
      retriable: true,
      details: ModelLoaderErrorDetails(backend: backend),
      suggestion: 'Check runtime installation or use alternative backend',
    );
  }

  factory ModelLoaderException.insufficientMemory({
    required int requiredMB,
    required int availableMB,
    String? modelId,
  }) {
    return ModelLoaderException(
      code: ModelLoaderErrorCode.INSUFFICIENT_MEMORY,
      message: 'Insufficient memory: need ${requiredMB}MB, have ${availableMB}MB',
      retriable: true,
      details: ModelLoaderErrorDetails(
        requiredMemoryMB: requiredMB,
        availableMemoryMB: availableMB,
        modelId: modelId,
      ),
      suggestion: 'Close other apps or use a smaller model',
    );
  }

  factory ModelLoaderException.downloadFailed({
    required String url,
    Object? error,
  }) {
    return ModelLoaderException(
      code: ModelLoaderErrorCode.DOWNLOAD_FAILED,
      message: 'Download failed: $url',
      retriable: true,
      originalError: error,
      suggestion: 'Check network connection and try again',
    );
  }
}
