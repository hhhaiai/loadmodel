import '../runtime/embedding_runtime.dart';
import '../runtime/llm_runtime.dart';
import 'inference_event.dart';
import 'inference_result.dart';

class InferenceEventMapper {
  static InferenceEvent fromLLMStreamEvent(LLMStreamEvent event) {
    return InferenceEvent(
      requestId: event.requestId,
      sequence: event.sequence,
      kind: switch (event.eventType) {
        LLMEventType.delta => InferenceEventKind.delta,
        LLMEventType.metrics => InferenceEventKind.metrics,
        LLMEventType.finish => InferenceEventKind.finish,
        LLMEventType.error => InferenceEventKind.error,
      },
      modality: InferenceModality.llm,
      timestamp: DateTime.now().toUtc(),
      textDelta: event.deltaText,
      stats: event.stats,
      finishReason: event.finishReason,
      error: event.error,
    );
  }

  static List<InferenceEvent> fromEmbeddingResult(
    EmbeddingResult result, {
    required String requestId,
  }) {
    return [
      InferenceEvent(
        requestId: requestId,
        sequence: 0,
        kind: InferenceEventKind.result,
        modality: InferenceModality.embedding,
        timestamp: DateTime.now().toUtc(),
        embeddingResult: result,
      ),
      InferenceEvent(
        requestId: requestId,
        sequence: 1,
        kind: InferenceEventKind.finish,
        modality: InferenceModality.embedding,
        timestamp: DateTime.now().toUtc(),
      ),
    ];
  }

  static List<InferenceEvent> fromOCRResult(
    OCRResult result, {
    required String requestId,
  }) {
    return [
      InferenceEvent(
        requestId: requestId,
        sequence: 0,
        kind: InferenceEventKind.result,
        modality: InferenceModality.ocr,
        timestamp: DateTime.now().toUtc(),
        ocrResult: result,
      ),
      InferenceEvent(
        requestId: requestId,
        sequence: 1,
        kind: InferenceEventKind.finish,
        modality: InferenceModality.ocr,
        timestamp: DateTime.now().toUtc(),
      ),
    ];
  }

  static List<InferenceEvent> fromSTTResult(
    STTResult result, {
    required String requestId,
  }) {
    return [
      InferenceEvent(
        requestId: requestId,
        sequence: 0,
        kind: InferenceEventKind.result,
        modality: InferenceModality.stt,
        timestamp: DateTime.now().toUtc(),
        sttResult: result,
      ),
      InferenceEvent(
        requestId: requestId,
        sequence: 1,
        kind: InferenceEventKind.finish,
        modality: InferenceModality.stt,
        timestamp: DateTime.now().toUtc(),
      ),
    ];
  }

  static List<InferenceEvent> fromTTSResult(
    TTSResult result, {
    required String requestId,
  }) {
    return [
      InferenceEvent(
        requestId: requestId,
        sequence: 0,
        kind: InferenceEventKind.result,
        modality: InferenceModality.tts,
        timestamp: DateTime.now().toUtc(),
        ttsResult: result,
      ),
      InferenceEvent(
        requestId: requestId,
        sequence: 1,
        kind: InferenceEventKind.finish,
        modality: InferenceModality.tts,
        timestamp: DateTime.now().toUtc(),
      ),
    ];
  }
}
