import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/models/inference_event.dart';
import 'package:model_loader/models/inference_event_mapper.dart';
import 'package:model_loader/models/inference_result.dart';
import 'package:model_loader/runtime/embedding_runtime.dart';
import 'package:model_loader/runtime/llm_runtime.dart';

void main() {
  group('InferenceEventMapper', () {
    test('maps LLM delta event to canonical inference event', () {
      final event = LLMStreamEvent.delta(
        requestId: 'chat_1',
        sequence: 2,
        deltaText: 'hello',
      );

      final mapped = InferenceEventMapper.fromLLMStreamEvent(event);

      expect(mapped.kind, InferenceEventKind.delta);
      expect(mapped.modality, InferenceModality.llm);
      expect(mapped.requestId, 'chat_1');
      expect(mapped.sequence, 2);
      expect(mapped.textDelta, 'hello');
    });

    test('maps LLM finish event to canonical inference event', () {
      final event = LLMStreamEvent.finish(
        requestId: 'chat_2',
        sequence: 3,
        finishReason: FinishReason.stop,
        stats: const GenerationStats(promptTokens: 1, completionTokens: 2),
      );

      final mapped = InferenceEventMapper.fromLLMStreamEvent(event);

      expect(mapped.kind, InferenceEventKind.finish);
      expect(mapped.finishReason, FinishReason.stop);
      expect(mapped.stats?.completionTokens, 2);
    });

    test('maps LLM error event to canonical inference event', () {
      final event = LLMStreamEvent.error(
        requestId: 'chat_3',
        sequence: 4,
        error: const LLMErrorInfo(code: 'STREAM_ERROR', message: 'boom'),
      );

      final mapped = InferenceEventMapper.fromLLMStreamEvent(event);

      expect(mapped.kind, InferenceEventKind.error);
      expect(mapped.error?.code, 'STREAM_ERROR');
      expect(mapped.error?.message, 'boom');
    });

    test('maps embedding result into result and finish events', () {
      final events = InferenceEventMapper.fromEmbeddingResult(
        const EmbeddingResult(embedding: [0.1, 0.2], dimension: 2),
        requestId: 'embedding_1',
      );

      expect(events.map((e) => e.kind), [InferenceEventKind.result, InferenceEventKind.finish]);
      expect(events.first.embeddingResult?.dimension, 2);
    });

    test('round-trips inference event json', () {
      final original = InferenceEvent(
        requestId: 'ocr_1',
        sequence: 0,
        kind: InferenceEventKind.result,
        modality: InferenceModality.ocr,
        timestamp: DateTime.utc(2026, 3, 8),
        ocrResult: const OCRResult(text: 'abc', blocks: [], averageConfidence: 0.8),
      );

      final decoded = InferenceEvent.fromJson(original.toJson());

      expect(decoded.requestId, original.requestId);
      expect(decoded.kind, original.kind);
      expect(decoded.modality, original.modality);
      expect(decoded.ocrResult?.text, 'abc');
    });
  });
}
