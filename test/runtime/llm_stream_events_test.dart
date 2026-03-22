import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/runtime/llm_runtime.dart';

class _FakeLLMRuntime implements LLMRuntime {
  _FakeLLMRuntime({
    required this.chunks,
    this.throwOnStream = false,
  });

  final List<String> chunks;
  final bool throwOnStream;

  @override
  Future<String> chat(List<ChatMessage> messages, {GenerationConfig? config}) async => chunks.join();

  @override
  Stream<String> chatStream(List<ChatMessage> messages, {GenerationConfig? config}) async* {
    if (throwOnStream) {
      throw StateError('stream failed');
    }
    for (final chunk in chunks) {
      yield chunk;
    }
  }

  @override
  Future<String> complete(String prompt, {GenerationConfig? config}) async => chunks.join();

  @override
  Stream<String> completeStream(String prompt, {GenerationConfig? config}) async* {
    if (throwOnStream) {
      throw StateError('stream failed');
    }
    for (final chunk in chunks) {
      yield chunk;
    }
  }

  @override
  bool get isLoaded => true;

  @override
  LLMModelInfo? get loadedModel => null;

  @override
  Future<void> loadModel(LLMConfig config) async {}

  @override
  Future<void> unloadModel() async {}
}

void main() {
  group('LLM structured stream events', () {
    test('chatStreamEvents emits delta/metrics/finish in order', () async {
      final runtime = _FakeLLMRuntime(chunks: ['hello ', 'world']);
      final events = await runtime.chatStreamEvents([ChatMessage.user('hi')]).toList();

      expect(events.map((e) => e.eventType), equals([
        LLMEventType.delta,
        LLMEventType.metrics,
        LLMEventType.delta,
        LLMEventType.metrics,
        LLMEventType.finish,
      ]));

      final requestId = events.first.requestId;
      expect(events.every((e) => e.requestId == requestId), isTrue);
      expect(events.map((e) => e.sequence), equals([0, 1, 2, 3, 4]));

      final firstDelta = events.firstWhere((e) => e.eventType == LLMEventType.delta);
      expect(firstDelta.deltaText, equals('hello '));

      final finish = events.last;
      expect(finish.finishReason, equals(FinishReason.stop));
      expect(finish.stats?.completionTokens, greaterThan(0));
    });

    test('chatStreamEvents emits error event on stream failure', () async {
      final runtime = _FakeLLMRuntime(chunks: const [], throwOnStream: true);
      final events = await runtime.chatStreamEvents([ChatMessage.user('hi')]).toList();

      expect(events.length, equals(1));
      expect(events.first.eventType, equals(LLMEventType.error));
      expect(events.first.error?.code, equals('STREAM_ERROR'));
      expect(events.first.error?.message, contains('stream failed'));
    });

    test('completeStreamEvents emits delta/metrics/finish in order', () async {
      final runtime = _FakeLLMRuntime(chunks: ['foo ', 'bar']);
      final events = await runtime.completeStreamEvents('prompt').toList();

      expect(events.map((e) => e.eventType), equals([
        LLMEventType.delta,
        LLMEventType.metrics,
        LLMEventType.delta,
        LLMEventType.metrics,
        LLMEventType.finish,
      ]));
      expect(events.map((e) => e.sequence), equals([0, 1, 2, 3, 4]));
      expect(events.last.finishReason, equals(FinishReason.stop));
    });

    test('completeStreamEvents emits error event on stream failure', () async {
      final runtime = _FakeLLMRuntime(chunks: const [], throwOnStream: true);
      final events = await runtime.completeStreamEvents('prompt').toList();

      expect(events.length, equals(1));
      expect(events.first.eventType, equals(LLMEventType.error));
      expect(events.first.error?.code, equals('STREAM_ERROR'));
    });
  });
}
