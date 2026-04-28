import '../runtime/embedding_runtime.dart';
import '../runtime/llm_runtime.dart';
import 'inference_result.dart';

enum InferenceEventKind {
  delta,
  metrics,
  result,
  finish,
  error,
}

enum InferenceModality {
  llm,
  embedding,
  ocr,
  stt,
  tts,
}

class InferenceEvent {
  final String requestId;
  final int sequence;
  final InferenceEventKind kind;
  final InferenceModality modality;
  final DateTime timestamp;
  final String? textDelta;
  final GenerationStats? stats;
  final FinishReason? finishReason;
  final LLMErrorInfo? error;
  final EmbeddingResult? embeddingResult;
  final OCRResult? ocrResult;
  final STTResult? sttResult;
  final TTSResult? ttsResult;

  const InferenceEvent({
    required this.requestId,
    required this.sequence,
    required this.kind,
    required this.modality,
    required this.timestamp,
    this.textDelta,
    this.stats,
    this.finishReason,
    this.error,
    this.embeddingResult,
    this.ocrResult,
    this.sttResult,
    this.ttsResult,
  });

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'sequence': sequence,
      'kind': kind.name,
      'modality': modality.name,
      'timestamp': timestamp.toUtc().toIso8601String(),
      if (textDelta != null) 'textDelta': textDelta,
      if (stats != null) 'stats': stats!.toJson(),
      if (finishReason != null) 'finishReason': finishReason!.name,
      if (error != null) 'error': error!.toJson(),
      if (embeddingResult != null)
        'embeddingResult': {
          'embedding': embeddingResult!.embedding,
          'dimension': embeddingResult!.dimension,
        },
      if (ocrResult != null) 'ocrResult': ocrResult!.toJson(),
      if (sttResult != null) 'sttResult': sttResult!.toJson(),
      if (ttsResult != null)
        'ttsResult': {
          'audioPath': ttsResult!.audioPath,
          'audioBytes': ttsResult!.audioBytes,
          'duration': ttsResult!.duration,
          'sampleRate': ttsResult!.sampleRate,
        },
    };
  }

  factory InferenceEvent.fromJson(Map<String, dynamic> json) {
    return InferenceEvent(
      requestId: json['requestId'] ?? '',
      sequence: json['sequence'] ?? 0,
      kind: InferenceEventKind.values.firstWhere(
        (value) => value.name == json['kind'],
        orElse: () => InferenceEventKind.result,
      ),
      modality: InferenceModality.values.firstWhere(
        (value) => value.name == json['modality'],
        orElse: () => InferenceModality.llm,
      ),
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      textDelta: json['textDelta'],
      stats: json['stats'] != null ? GenerationStats.fromJson(Map<String, dynamic>.from(json['stats'])) : null,
      finishReason: json['finishReason'] != null ? FinishReasonExtension.fromString(json['finishReason']) : null,
      error: json['error'] != null ? LLMErrorInfo.fromJson(Map<String, dynamic>.from(json['error'])) : null,
      embeddingResult: json['embeddingResult'] != null
          ? EmbeddingResult.fromJson(Map<String, dynamic>.from(json['embeddingResult']))
          : null,
      ocrResult: json['ocrResult'] != null ? OCRResult.fromJson(Map<String, dynamic>.from(json['ocrResult'])) : null,
      sttResult: json['sttResult'] != null ? STTResult.fromJson(Map<String, dynamic>.from(json['sttResult'])) : null,
      ttsResult: json['ttsResult'] != null
          ? TTSResult(
              audioPath: json['ttsResult']['audioPath'],
              audioBytes: json['ttsResult']['audioBytes'] != null
                  ? List<int>.from(json['ttsResult']['audioBytes'])
                  : null,
              duration: (json['ttsResult']['duration'] ?? 0.0).toDouble(),
              sampleRate: json['ttsResult']['sampleRate'] ?? 16000,
            )
          : null,
    );
  }
}
