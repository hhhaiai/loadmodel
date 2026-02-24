/// RuntimeSelector - Backend selection and downgrade logic
/// Reference: CLAUDE.md Section 4

import 'dart:math';
import '../core/platform_utils.dart';
import '../models/model_type.dart';
import '../models/model_manifest.dart';

/// Backend type
enum BackendType {
  llamaCpp,
  onnx,
  tflite,
  mediaPipe,
  vosk,
  whisperCpp,
}

/// Provider type (hardware acceleration)
enum ProviderType {
  gpu,
  cpu,
}

/// Candidate backend
class BackendCandidate {
  final BackendType backend;
  final ProviderType provider;
  final bool accepted;
  final List<String> reasons;

  const BackendCandidate({
    required this.backend,
    required this.provider,
    required this.accepted,
    required this.reasons,
  });

  Map<String, dynamic> toJson() {
    return {
      'backend': backend.name,
      'provider': provider.name,
      'accepted': accepted,
      'reasons': reasons,
    };
  }
}

/// Downgrade step
class DowngradeStep {
  final String dimension;
  final dynamic from;
  final dynamic to;

  const DowngradeStep({
    required this.dimension,
    required this.from,
    required this.to,
  });

  Map<String, dynamic> toJson() {
    return {
      'dimension': dimension,
      'from': from,
      'to': to,
    };
  }
}

/// Final decision
class FinalDecision {
  final BackendType backend;
  final ProviderType provider;
  final String? quantization;
  final int contextLength;
  final int threads;
  final int gpuLayers;

  const FinalDecision({
    required this.backend,
    required this.provider,
    this.quantization,
    required this.contextLength,
    required this.threads,
    required this.gpuLayers,
  });

  Map<String, dynamic> toJson() {
    return {
      'backend': backend.name,
      'provider': provider.name,
      'quantization': quantization,
      'contextLength': contextLength,
      'threads': threads,
      'gpuLayers': gpuLayers,
    };
  }
}

/// Selection report (matches CLAUDE.md Section 4.2)
class SelectionReport {
  final String requestId;
  final List<BackendCandidate> candidates;
  final List<DowngradeStep> downgradeSteps;
  final FinalDecision finalDecision;

  const SelectionReport({
    required this.requestId,
    required this.candidates,
    required this.downgradeSteps,
    required this.finalDecision,
  });

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'candidates': candidates.map((c) => c.toJson()).toList(),
      'downgradeSteps': downgradeSteps.map((d) => d.toJson()).toList(),
      'finalDecision': finalDecision.toJson(),
    };
  }
}

/// Context length options (per CLAUDE.md Section 4.1)
class ContextLengthOptions {
  static const List<int> values = [8192, 4096, 2048];

  static int getDefault() => values.first;

  static int? getNext(int current) {
    final index = values.indexOf(current);
    if (index == -1 || index == values.length - 1) return null;
    return values[index + 1];
  }
}

/// RuntimeSelector - selects best backend with downgrade logic
class RuntimeSelector {
  final String platformName;
  final int availableMemoryMB;
  final int cpuCores;

  RuntimeSelector({
    required this.platformName,
    required this.availableMemoryMB,
    required this.cpuCores,
  });

  /// Select best runtime for model
  /// Reference: CLAUDE.md Section 4
  SelectionReport select({
    required ModelManifestItem model,
    String? preferredBackend,
    String? preferredProvider,
  }) {
    final requestId = 'sel_${DateTime.now().millisecondsSinceEpoch}';
    final candidates = <BackendCandidate>[];
    final downgradeSteps = <DowngradeStep>[];

    // Step 1: Filter by platform
    if (model.platforms.isNotEmpty &&
        !model.platforms.contains(platformName)) {
      return _createFailedReport(
        requestId,
        'Platform not supported: $platformName',
        candidates,
        downgradeSteps,
      );
    }

    // Step 2: Check backend hints
    BackendType? selectedBackend;
    ProviderType selectedProvider = ProviderType.cpu;

    if (preferredBackend != null) {
      selectedBackend = _parseBackend(preferredBackend);
      selectedProvider = _parseProvider(preferredProvider) ?? ProviderType.cpu;
    } else if (model.backendHints.isNotEmpty) {
      // Try each backend hint in order
      for (final hint in model.backendHints) {
        final backend = _parseBackend(hint);
        if (backend != null && _isBackendAvailable(backend)) {
          selectedBackend = backend;
          break;
        }
      }
    }

    // Default to onnx if no backend selected
    selectedBackend ??= BackendType.onnx;

    // Step 3: Check memory requirements
    final modelMemoryMB = model.metadata?['minMemoryMB'] as int? ?? 2048;

    if (availableMemoryMB < modelMemoryMB) {
      candidates.add(BackendCandidate(
        backend: selectedBackend,
        provider: selectedProvider,
        accepted: false,
        reasons: ['INSUFFICIENT_MEMORY'],
      ));

      // Try with lower quantization
      if (model.quantization != null) {
        downgradeSteps.add(DowngradeStep(
          dimension: 'quantization',
          from: model.quantization,
          to: 'Q4_K_M',
        ));
      }

      // Try with shorter context
      if (model.contextLength != null && model.contextLength! > 2048) {
        final nextContext = ContextLengthOptions.getNext(model.contextLength!);
        if (nextContext != null) {
          downgradeSteps.add(DowngradeStep(
            dimension: 'contextLength',
            from: model.contextLength,
            to: nextContext,
          ));
        }
      }

      // Reduce threads
      final threads = _calculateThreads(cpuCores);
      final gpuLayers = 0; // Disable GPU if memory insufficient

      return SelectionReport(
        requestId: requestId,
        candidates: candidates,
        downgradeSteps: downgradeSteps,
        finalDecision: FinalDecision(
          backend: selectedBackend,
          provider: ProviderType.cpu,
          quantization: downgradeSteps.any((s) => s.dimension == 'quantization')
              ? 'Q4_K_M'
              : model.quantization,
          contextLength: downgradeSteps
                  .firstWhere(
                    (s) => s.dimension == 'contextLength',
                    orElse: () => DowngradeStep(
                      dimension: '',
                      from: 0,
                      to: model.contextLength ?? 4096,
                    ),
                  )
                  .to as int? ??
              4096,
          threads: threads,
          gpuLayers: gpuLayers,
        ),
      );
    }

    // Step 4: Check hardware acceleration availability
    final hasGpu = _hasGpuAcceleration();

    if (hasGpu) {
      selectedProvider = ProviderType.gpu;
    }

    // Create final decision
    final threads = _calculateThreads(cpuCores);
    final gpuLayers = _calculateGpuLayers(selectedBackend, hasGpu);

    candidates.add(BackendCandidate(
      backend: selectedBackend,
      provider: selectedProvider,
      accepted: true,
      reasons: [],
    ));

    return SelectionReport(
      requestId: requestId,
      candidates: candidates,
      downgradeSteps: downgradeSteps,
      finalDecision: FinalDecision(
        backend: selectedBackend,
        provider: selectedProvider,
        quantization: model.quantization,
        contextLength: model.contextLength ?? 4096,
        threads: threads,
        gpuLayers: gpuLayers,
      ),
    );
  }

  /// Parse backend string to BackendType
  BackendType? _parseBackend(String name) {
    switch (name.toLowerCase()) {
      case 'llama.cpp':
      case 'llamacpp':
        return BackendType.llamaCpp;
      case 'onnx':
      case 'onnxruntime':
        return BackendType.onnx;
      case 'tflite':
      case 'tensorflowlite':
        return BackendType.tflite;
      case 'mediapipe':
        return BackendType.mediaPipe;
      case 'vosk':
        return BackendType.vosk;
      case 'whisper.cpp':
      case 'whispercpp':
        return BackendType.whisperCpp;
      default:
        return null;
    }
  }

  /// Parse provider string to ProviderType
  ProviderType? _parseProvider(String? name) {
    if (name == null) return null;
    switch (name.toLowerCase()) {
      case 'gpu':
      case 'cuda':
      case 'metal':
      case 'core ml':
        return ProviderType.gpu;
      case 'cpu':
        return ProviderType.cpu;
      default:
        return null;
    }
  }

  /// Check if backend is available
  bool _isBackendAvailable(BackendType backend) {
    // Check based on platform
    switch (backend) {
      case BackendType.llamaCpp:
        return platformName == 'macos' ||
            platformName == 'windows' ||
            platformName == 'linux';
      case BackendType.onnx:
      case BackendType.tflite:
        return true; // Cross-platform
      case BackendType.mediaPipe:
        return platformName == 'android' || platformName == 'ios';
      case BackendType.vosk:
      case BackendType.whisperCpp:
        return true;
    }
  }

  /// Check if GPU acceleration is available
  bool _hasGpuAcceleration() {
    switch (platformName) {
      case 'ios':
        return true; // CoreML
      case 'android':
        return true; // NNAPI
      case 'macos':
        return true; // Metal
      case 'windows':
      case 'linux':
        return false; // Would check CUDA/Vulkan
      default:
        return false;
    }
  }

  /// Calculate optimal thread count (per CLAUDE.md Section 4.1)
  int _calculateThreads(int cpuCores) {
    return max(1, cpuCores - 1);
  }

  /// Calculate GPU layers
  int _calculateGpuLayers(BackendType backend, bool hasGpu) {
    if (!hasGpu) return 0;

    switch (backend) {
      case BackendType.llamaCpp:
        return 32; // Default for llama.cpp
      case BackendType.onnx:
        return 0; // ONNX uses CPU with CoreML/NNAPI
      default:
        return 0;
    }
  }

  /// Create failed report
  SelectionReport _createFailedReport(
    String requestId,
    String reason,
    List<BackendCandidate> candidates,
    List<DowngradeStep> downgradeSteps,
  ) {
    return SelectionReport(
      requestId: requestId,
      candidates: candidates,
      downgradeSteps: downgradeSteps,
      finalDecision: FinalDecision(
        backend: BackendType.onnx,
        provider: ProviderType.cpu,
        contextLength: 4096,
        threads: _calculateThreads(cpuCores),
        gpuLayers: 0,
      ),
    );
  }

  /// Create selector for current platform
  factory RuntimeSelector.currentPlatform({
    int? availableMemoryMB,
    int? cpuCores,
  }) {
    final platform = PlatformUtils.platformName;

    return RuntimeSelector(
      platformName: platform,
      availableMemoryMB: availableMemoryMB ?? 4096,
      cpuCores: cpuCores ?? PlatformUtils.processorCount,
    );
  }
}
