import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/models/inference_event.dart';
import 'package:model_loader/models/inference_event_mapper.dart';
import 'package:model_loader/models/inference_result.dart';
import 'package:model_loader/runtime/embedding_runtime.dart';
import 'package:model_loader/runtime/llm_runtime.dart';

void main() {
  group('InferenceEventMapper', () {
    group('fromEmbeddingResult', () {
      test('returns list with 2 events in correct order', () {
        const result = EmbeddingResult(
          embedding: [0.1, 0.2, 0.3],
          dimension: 3,
        );

        final events = InferenceEventMapper.fromEmbeddingResult(
          result,
          requestId: 'req-123',
        );

        expect(events.length, equals(2));
        expect(events[0].sequence, equals(0));
        expect(events[1].sequence, equals(1));
      });

      test('first event has result kind with embedding modality', () {
        const result = EmbeddingResult(
          embedding: [0.1, 0.2],
          dimension: 2,
        );

        final events = InferenceEventMapper.fromEmbeddingResult(
          result,
          requestId: 'req-456',
        );

        expect(events[0].kind, equals(InferenceEventKind.result));
        expect(events[0].modality, equals(InferenceModality.embedding));
        expect(events[0].requestId, equals('req-456'));
        expect(events[0].embeddingResult, equals(result));
      });

      test('second event has finish kind with embedding modality', () {
        const result = EmbeddingResult(
          embedding: [0.1, 0.2],
          dimension: 2,
        );

        final events = InferenceEventMapper.fromEmbeddingResult(
          result,
          requestId: 'req-789',
        );

        expect(events[1].kind, equals(InferenceEventKind.finish));
        expect(events[1].modality, equals(InferenceModality.embedding));
        expect(events[1].requestId, equals('req-789'));
      });

      test('both events have valid timestamps', () {
        const result = EmbeddingResult(
          embedding: [0.1],
          dimension: 1,
        );

        final events = InferenceEventMapper.fromEmbeddingResult(
          result,
          requestId: 'req-time',
        );

        expect(events[0].timestamp, isNotNull);
        expect(events[1].timestamp, isNotNull);
        expect(
          events[1].timestamp.isAfter(events[0].timestamp) ||
              events[1].timestamp.isAtSameMomentAs(events[0].timestamp),
          isTrue,
        );
      });

      test('handles empty embedding list', () {
        const result = EmbeddingResult(
          embedding: [],
          dimension: 0,
        );

        final events = InferenceEventMapper.fromEmbeddingResult(
          result,
          requestId: 'req-empty',
        );

        expect(events.length, equals(2));
        expect(events[0].embeddingResult!.embedding, isEmpty);
        expect(events[0].embeddingResult!.dimension, equals(0));
      });
    });

    group('fromOCRResult', () {
      test('returns list with 2 events in correct order', () {
        const result = OCRResult(
          text: 'Hello World',
          blocks: [],
        );

        final events = InferenceEventMapper.fromOCRResult(
          result,
          requestId: 'req-123',
        );

        expect(events.length, equals(2));
        expect(events[0].sequence, equals(0));
        expect(events[1].sequence, equals(1));
      });

      test('first event has result kind with ocr modality', () {
        const block = OCRBlock(text: 'Test', confidence: 0.9);
        const result = OCRResult(
          text: 'Test',
          blocks: [block],
          averageConfidence: 0.9,
        );

        final events = InferenceEventMapper.fromOCRResult(
          result,
          requestId: 'req-456',
        );

        expect(events[0].kind, equals(InferenceEventKind.result));
        expect(events[0].modality, equals(InferenceModality.ocr));
        expect(events[0].requestId, equals('req-456'));
        expect(events[0].ocrResult, equals(result));
        expect(events[0].ocrResult!.text, equals('Test'));
        expect(events[0].ocrResult!.blocks.length, equals(1));
      });

      test('second event has finish kind with ocr modality', () {
        const result = OCRResult(
          text: 'Test',
          blocks: [],
        );

        final events = InferenceEventMapper.fromOCRResult(
          result,
          requestId: 'req-789',
        );

        expect(events[1].kind, equals(InferenceEventKind.finish));
        expect(events[1].modality, equals(InferenceModality.ocr));
        expect(events[1].requestId, equals('req-789'));
      });

      test('handles empty text result', () {
        const result = OCRResult(
          text: '',
          blocks: [],
        );

        final events = InferenceEventMapper.fromOCRResult(
          result,
          requestId: 'req-empty',
        );

        expect(events.length, equals(2));
        expect(events[0].ocrResult!.text, equals(''));
        expect(events[0].ocrResult!.blocks, isEmpty);
      });

      test('preserves bounding box information', () {
        const box = Rect(left: 10, top: 20, width: 100, height: 50);
        const block = OCRBlock(
          text: 'Hello',
          confidence: 0.95,
          boundingBox: box,
        );
        const result = OCRResult(
          text: 'Hello',
          blocks: [block],
          averageConfidence: 0.95,
        );

        final events = InferenceEventMapper.fromOCRResult(
          result,
          requestId: 'req-bbox',
        );

        expect(events[0].ocrResult!.blocks[0].boundingBox, equals(box));
        expect(events[0].ocrResult!.blocks[0].boundingBox!.left, equals(10));
        expect(events[0].ocrResult!.blocks[0].boundingBox!.top, equals(20));
      });
    });

    group('fromSTTResult', () {
      test('returns list with 2 events in correct order', () {
        const result = STTResult(text: 'Hello');

        final events = InferenceEventMapper.fromSTTResult(
          result,
          requestId: 'req-123',
        );

        expect(events.length, equals(2));
        expect(events[0].sequence, equals(0));
        expect(events[1].sequence, equals(1));
      });

      test('first event has result kind with stt modality', () {
        const segment = STTSegment(
          start: 0.0,
          end: 1.5,
          text: 'Hello',
          confidence: 0.95,
        );
        const result = STTResult(
          text: 'Hello',
          segments: [segment],
          language: 'en',
          confidence: 0.9,
        );

        final events = InferenceEventMapper.fromSTTResult(
          result,
          requestId: 'req-456',
        );

        expect(events[0].kind, equals(InferenceEventKind.result));
        expect(events[0].modality, equals(InferenceModality.stt));
        expect(events[0].requestId, equals('req-456'));
        expect(events[0].sttResult, equals(result));
        expect(events[0].sttResult!.text, equals('Hello'));
        expect(events[0].sttResult!.language, equals('en'));
        expect(events[0].sttResult!.segments.length, equals(1));
      });

      test('second event has finish kind with stt modality', () {
        const result = STTResult(text: 'Test');

        final events = InferenceEventMapper.fromSTTResult(
          result,
          requestId: 'req-789',
        );

        expect(events[1].kind, equals(InferenceEventKind.finish));
        expect(events[1].modality, equals(InferenceModality.stt));
        expect(events[1].requestId, equals('req-789'));
      });

      test('handles empty text result', () {
        const result = STTResult(
          text: '',
          segments: [],
        );

        final events = InferenceEventMapper.fromSTTResult(
          result,
          requestId: 'req-empty',
        );

        expect(events.length, equals(2));
        expect(events[0].sttResult!.text, equals(''));
        expect(events[0].sttResult!.segments, isEmpty);
      });

      test('preserves segment timing information', () {
        const segment1 = STTSegment(
          start: 0.0,
          end: 1.0,
          text: 'Hello',
          confidence: 0.95,
        );
        const segment2 = STTSegment(
          start: 1.0,
          end: 2.5,
          text: 'World',
          confidence: 0.9,
        );
        const result = STTResult(
          text: 'Hello World',
          segments: [segment1, segment2],
        );

        final events = InferenceEventMapper.fromSTTResult(
          result,
          requestId: 'req-segments',
        );

        expect(events[0].sttResult!.segments.length, equals(2));
        expect(events[0].sttResult!.segments[0].start, equals(0.0));
        expect(events[0].sttResult!.segments[0].end, equals(1.0));
        expect(events[0].sttResult!.segments[1].start, equals(1.0));
        expect(events[0].sttResult!.segments[1].end, equals(2.5));
      });
    });

    group('fromTTSResult', () {
      test('returns list with 2 events in correct order', () {
        const result = TTSResult(
          audioPath: '/path/to/audio.wav',
          duration: 2.5,
          sampleRate: 44100,
        );

        final events = InferenceEventMapper.fromTTSResult(
          result,
          requestId: 'req-123',
        );

        expect(events.length, equals(2));
        expect(events[0].sequence, equals(0));
        expect(events[1].sequence, equals(1));
      });

      test('first event has result kind with tts modality', () {
        const result = TTSResult(
          audioPath: '/path/to/audio.wav',
          duration: 2.5,
          sampleRate: 44100,
        );

        final events = InferenceEventMapper.fromTTSResult(
          result,
          requestId: 'req-456',
        );

        expect(events[0].kind, equals(InferenceEventKind.result));
        expect(events[0].modality, equals(InferenceModality.tts));
        expect(events[0].requestId, equals('req-456'));
        expect(events[0].ttsResult, equals(result));
        expect(events[0].ttsResult!.audioPath, equals('/path/to/audio.wav'));
        expect(events[0].ttsResult!.duration, equals(2.5));
        expect(events[0].ttsResult!.sampleRate, equals(44100));
      });

      test('second event has finish kind with tts modality', () {
        const result = TTSResult(
          audioPath: '/path/to/audio.wav',
        );

        final events = InferenceEventMapper.fromTTSResult(
          result,
          requestId: 'req-789',
        );

        expect(events[1].kind, equals(InferenceEventKind.finish));
        expect(events[1].modality, equals(InferenceModality.tts));
        expect(events[1].requestId, equals('req-789'));
      });

      test('handles result with audioBytes instead of audioPath', () {
        const result = TTSResult(
          audioBytes: [1, 2, 3, 4],
          duration: 1.0,
        );

        final events = InferenceEventMapper.fromTTSResult(
          result,
          requestId: 'req-bytes',
        );

        expect(events[0].ttsResult!.audioPath, isNull);
        expect(events[0].ttsResult!.audioBytes, isNotNull);
        expect(events[0].ttsResult!.audioBytes!.length, equals(4));
      });

      test('handles result with default sampleRate', () {
        const result = TTSResult(
          audioPath: '/default.wav',
        );

        final events = InferenceEventMapper.fromTTSResult(
          result,
          requestId: 'req-default',
        );

        expect(events[0].ttsResult!.sampleRate, equals(16000));
      });
    });

    group('fromLLMStreamEvent', () {
      test('maps delta event type correctly', () {
        const event = LLMStreamEvent(
          eventType: LLMEventType.delta,
          requestId: 'req-delta',
          sequence: 0,
          deltaText: 'Hello',
        );

        final result = InferenceEventMapper.fromLLMStreamEvent(event);

        expect(result.kind, equals(InferenceEventKind.delta));
        expect(result.modality, equals(InferenceModality.llm));
        expect(result.requestId, equals('req-delta'));
        expect(result.sequence, equals(0));
        expect(result.textDelta, equals('Hello'));
      });

      test('maps metrics event type correctly', () {
        const stats = GenerationStats(
          promptTokens: 10,
          completionTokens: 20,
        );
        const event = LLMStreamEvent(
          eventType: LLMEventType.metrics,
          requestId: 'req-metrics',
          sequence: 1,
          stats: stats,
        );

        final result = InferenceEventMapper.fromLLMStreamEvent(event);

        expect(result.kind, equals(InferenceEventKind.metrics));
        expect(result.stats, equals(stats));
        expect(result.textDelta, isNull);
      });

      test('maps finish event type correctly', () {
        const event = LLMStreamEvent(
          eventType: LLMEventType.finish,
          requestId: 'req-finish',
          sequence: 2,
          finishReason: FinishReason.eos,
        );

        final result = InferenceEventMapper.fromLLMStreamEvent(event);

        expect(result.kind, equals(InferenceEventKind.finish));
        expect(result.finishReason, equals(FinishReason.eos));
      });

      test('maps error event type correctly', () {
        const errorInfo = LLMErrorInfo(
          code: 'INVALID_REQUEST',
          message: 'Bad request',
          retriable: false,
        );
        const event = LLMStreamEvent(
          eventType: LLMEventType.error,
          requestId: 'req-error',
          sequence: 3,
          error: errorInfo,
        );

        final result = InferenceEventMapper.fromLLMStreamEvent(event);

        expect(result.kind, equals(InferenceEventKind.error));
        expect(result.error, equals(errorInfo));
        expect(result.error!.code, equals('INVALID_REQUEST'));
      });

      test('preserves all event properties', () {
        const stats = GenerationStats(
          promptTokens: 5,
          completionTokens: 15,
          timeToFirstTokenMs: 100,
          msPerToken: 50,
        );
        const event = LLMStreamEvent(
          eventType: LLMEventType.metrics,
          requestId: 'req-full',
          sequence: 5,
          deltaText: 'partial',
          tokenIds: [1, 2, 3],
          stats: stats,
          finishReason: FinishReason.length,
        );

        final result = InferenceEventMapper.fromLLMStreamEvent(event);

        expect(result.requestId, equals('req-full'));
        expect(result.sequence, equals(5));
        expect(result.textDelta, equals('partial'));
        expect(result.stats, equals(stats));
        expect(result.finishReason, equals(FinishReason.length));
      });
    });

    group('event list structure verification', () {
      test('all fromXResult functions return events with incrementing sequences', () {
        const embeddingResult = EmbeddingResult(embedding: [0.1], dimension: 1);
        const ocrResult = OCRResult(text: 'test', blocks: []);
        const sttResult = STTResult(text: 'test');
        const ttsResult = TTSResult(audioPath: '/test.wav');
        const requestId = 'req-sequence';

        final embeddingEvents =
            InferenceEventMapper.fromEmbeddingResult(embeddingResult, requestId: requestId);
        final ocrEvents =
            InferenceEventMapper.fromOCRResult(ocrResult, requestId: requestId);
        final sttEvents =
            InferenceEventMapper.fromSTTResult(sttResult, requestId: requestId);
        final ttsEvents =
            InferenceEventMapper.fromTTSResult(ttsResult, requestId: requestId);

        for (final events in [embeddingEvents, ocrEvents, sttEvents, ttsEvents]) {
          expect(events.length, equals(2));
          expect(events[0].sequence, equals(0));
          expect(events[1].sequence, equals(1));
          expect(events[1].sequence, equals(events[0].sequence + 1));
        }
      });

      test('all events in list share the same requestId', () {
        const embeddingResult = EmbeddingResult(embedding: [0.1], dimension: 1);
        const ocrResult = OCRResult(text: 'test', blocks: []);
        const sttResult = STTResult(text: 'test');
        const ttsResult = TTSResult(audioPath: '/test.wav');
        const requestId = 'req-shared-123';

        final embeddingEvents =
            InferenceEventMapper.fromEmbeddingResult(embeddingResult, requestId: requestId);
        final ocrEvents =
            InferenceEventMapper.fromOCRResult(ocrResult, requestId: requestId);
        final sttEvents =
            InferenceEventMapper.fromSTTResult(sttResult, requestId: requestId);
        final ttsEvents =
            InferenceEventMapper.fromTTSResult(ttsResult, requestId: requestId);

        for (final events in [embeddingEvents, ocrEvents, sttEvents, ttsEvents]) {
          expect(events[0].requestId, equals(requestId));
          expect(events[1].requestId, equals(requestId));
        }
      });

      test('all fromXResult functions produce finish event as second event', () {
        const embeddingResult = EmbeddingResult(embedding: [0.1], dimension: 1);
        const ocrResult = OCRResult(text: 'test', blocks: []);
        const sttResult = STTResult(text: 'test');
        const ttsResult = TTSResult(audioPath: '/test.wav');

        final embeddingEvents =
            InferenceEventMapper.fromEmbeddingResult(embeddingResult, requestId: 'req');
        final ocrEvents =
            InferenceEventMapper.fromOCRResult(ocrResult, requestId: 'req');
        final sttEvents =
            InferenceEventMapper.fromSTTResult(sttResult, requestId: 'req');
        final ttsEvents =
            InferenceEventMapper.fromTTSResult(ttsResult, requestId: 'req');

        expect(embeddingEvents[1].kind, equals(InferenceEventKind.finish));
        expect(ocrEvents[1].kind, equals(InferenceEventKind.finish));
        expect(sttEvents[1].kind, equals(InferenceEventKind.finish));
        expect(ttsEvents[1].kind, equals(InferenceEventKind.finish));
      });

      test('all fromXResult functions produce result event as first event', () {
        const embeddingResult = EmbeddingResult(embedding: [0.1], dimension: 1);
        const ocrResult = OCRResult(text: 'test', blocks: []);
        const sttResult = STTResult(text: 'test');
        const ttsResult = TTSResult(audioPath: '/test.wav');

        final embeddingEvents =
            InferenceEventMapper.fromEmbeddingResult(embeddingResult, requestId: 'req');
        final ocrEvents =
            InferenceEventMapper.fromOCRResult(ocrResult, requestId: 'req');
        final sttEvents =
            InferenceEventMapper.fromSTTResult(sttResult, requestId: 'req');
        final ttsEvents =
            InferenceEventMapper.fromTTSResult(ttsResult, requestId: 'req');

        expect(embeddingEvents[0].kind, equals(InferenceEventKind.result));
        expect(ocrEvents[0].kind, equals(InferenceEventKind.result));
        expect(sttEvents[0].kind, equals(InferenceEventKind.result));
        expect(ttsEvents[0].kind, equals(InferenceEventKind.result));
      });
    });
  });
}
