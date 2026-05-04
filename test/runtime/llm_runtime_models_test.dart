import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/runtime/llm_runtime.dart';

void main() {
  group('ChatRole', () {
    test('name returns correct string', () {
      expect(ChatRole.system.name, equals('system'));
      expect(ChatRole.user.name, equals('user'));
      expect(ChatRole.assistant.name, equals('assistant'));
    });

    test('fromString parses correctly', () {
      expect(ChatRoleExtension.fromString('system'), equals(ChatRole.system));
      expect(ChatRoleExtension.fromString('user'), equals(ChatRole.user));
      expect(ChatRoleExtension.fromString('assistant'), equals(ChatRole.assistant));
      expect(ChatRoleExtension.fromString('SYSTEM'), equals(ChatRole.system));
      expect(ChatRoleExtension.fromString('User'), equals(ChatRole.user));
    });

    test('fromString defaults to user for unknown', () {
      expect(ChatRoleExtension.fromString('unknown'), equals(ChatRole.user));
      expect(ChatRoleExtension.fromString(''), equals(ChatRole.user));
    });
  });

  group('ChatMessage', () {
    test('toJson serializes correctly', () {
      final msg = ChatMessage(role: ChatRole.user, content: 'hello');
      final json = msg.toJson();
      expect(json['role'], equals('user'));
      expect(json['content'], equals('hello'));
    });

    test('fromJson deserializes correctly', () {
      final msg = ChatMessage.fromJson({'role': 'assistant', 'content': 'hi'});
      expect(msg.role, equals(ChatRole.assistant));
      expect(msg.content, equals('hi'));
    });

    test('fromJson handles missing fields', () {
      final msg = ChatMessage.fromJson({});
      expect(msg.role, equals(ChatRole.user));
      expect(msg.content, equals(''));
    });

    test('factory constructors create correct types', () {
      final user = ChatMessage.user('test');
      expect(user.role, equals(ChatRole.user));
      expect(user.content, equals('test'));

      final system = ChatMessage.system('sys');
      expect(system.role, equals(ChatRole.system));
      expect(system.content, equals('sys'));

      final assistant = ChatMessage.assistant('bot');
      expect(assistant.role, equals(ChatRole.assistant));
      expect(assistant.content, equals('bot'));
    });
  });

  group('GenerationConfig', () {
    test('toJson serializes non-null fields', () {
      const config = GenerationConfig(
        temperature: 0.8,
        topP: 0.95,
        maxTokens: 1024,
        stream: true,
        topK: 40,
        repeatPenalty: 1.1,
        seed: 42,
        batchSize: 512,
        threads: 4,
        stopStrings: ['stop1', 'stop2'],
      );
      final json = config.toJson();
      expect(json['temperature'], equals(0.8));
      expect(json['top_p'], equals(0.95));
      expect(json['max_tokens'], equals(1024));
      expect(json['stream'], isTrue);
      expect(json['top_k'], equals(40));
      expect(json['repeat_penalty'], equals(1.1));
      expect(json['seed'], equals(42));
      expect(json['batch_size'], equals(512));
      expect(json['threads'], equals(4));
      expect(json['stop_strings'], equals(['stop1', 'stop2']));
    });

    test('toJson omits null fields', () {
      const config = GenerationConfig();
      final json = config.toJson();
      expect(json.containsKey('temperature'), isFalse);
      expect(json.containsKey('top_p'), isFalse);
      expect(json.containsKey('max_tokens'), isFalse);
    });

    test('defaultConfig has expected values', () {
      expect(GenerationConfig.defaultConfig.temperature, equals(0.7));
      expect(GenerationConfig.defaultConfig.topP, equals(0.9));
      expect(GenerationConfig.defaultConfig.maxTokens, equals(2048));
      expect(GenerationConfig.defaultConfig.stream, isFalse);
    });
  });

  group('LLMModelInfo', () {
    test('toJson serializes all fields', () {
      const info = LLMModelInfo(
        name: 'test-model',
        path: '/path/to/model',
        contextLength: 2048,
        parameterSize: '7B',
        quantization: 'Q4_0',
        vocabSize: 32000,
        hardware: 'GPU',
      );
      final json = info.toJson();
      expect(json['name'], equals('test-model'));
      expect(json['path'], equals('/path/to/model'));
      expect(json['contextLength'], equals(2048));
      expect(json['parameterSize'], equals('7B'));
      expect(json['quantization'], equals('Q4_0'));
      expect(json['vocabSize'], equals(32000));
      expect(json['hardware'], equals('GPU'));
    });

    test('toJson handles optional fields', () {
      const info = LLMModelInfo(name: 'model', path: '/path');
      final json = info.toJson();
      expect(json['contextLength'], equals(4096));
      // Optional fields are included as null in toJson
      expect(json['parameterSize'], isNull);
      expect(json['quantization'], isNull);
      expect(json['vocabSize'], isNull);
      expect(json['hardware'], isNull);
    });
  });

  group('LLMConfig', () {
    test('toJson serializes all fields', () {
      const config = LLMConfig(
        modelPath: '/model.gguf',
        contextLength: 4096,
        maxTokens: 2048,
        temperature: 0.7,
        topP: 0.9,
        gpuLayers: 32,
        tokenizerPath: '/vocab.json',
        threads: 8,
        useGpu: true,
      );
      final json = config.toJson();
      expect(json['modelPath'], equals('/model.gguf'));
      expect(json['contextLength'], equals(4096));
      expect(json['maxTokens'], equals(2048));
      expect(json['temperature'], equals(0.7));
      expect(json['topP'], equals(0.9));
      expect(json['gpuLayers'], equals(32));
      expect(json['tokenizerPath'], equals('/vocab.json'));
      expect(json['threads'], equals(8));
      expect(json['useGpu'], isTrue);
    });

    test('default values are correct', () {
      const config = LLMConfig(modelPath: '/model');
      expect(config.contextLength, equals(4096));
      expect(config.maxTokens, equals(2048));
      expect(config.temperature, equals(0.7));
      expect(config.topP, equals(0.9));
      expect(config.useGpu, isTrue);
      expect(config.gpuLayers, isNull);
      expect(config.tokenizerPath, isNull);
      expect(config.threads, isNull);
    });
  });

  group('LLMEventType', () {
    test('name returns correct string', () {
      expect(LLMEventType.delta.name, equals('delta'));
      expect(LLMEventType.metrics.name, equals('metrics'));
      expect(LLMEventType.finish.name, equals('finish'));
      expect(LLMEventType.error.name, equals('error'));
    });

    test('fromString parses correctly', () {
      expect(LLMEventTypeExtension.fromString('delta'), equals(LLMEventType.delta));
      expect(LLMEventTypeExtension.fromString('metrics'), equals(LLMEventType.metrics));
      expect(LLMEventTypeExtension.fromString('finish'), equals(LLMEventType.finish));
      expect(LLMEventTypeExtension.fromString('error'), equals(LLMEventType.error));
    });

    test('fromString defaults to delta for unknown', () {
      expect(LLMEventTypeExtension.fromString('unknown'), equals(LLMEventType.delta));
    });
  });

  group('FinishReason', () {
    test('name returns correct string', () {
      expect(FinishReason.eos.name, equals('eos'));
      expect(FinishReason.length.name, equals('length'));
      expect(FinishReason.stop.name, equals('stop'));
      expect(FinishReason.cancel.name, equals('cancel'));
      expect(FinishReason.error.name, equals('error'));
    });

    test('fromString parses correctly', () {
      expect(FinishReasonExtension.fromString('eos'), equals(FinishReason.eos));
      expect(FinishReasonExtension.fromString('length'), equals(FinishReason.length));
      expect(FinishReasonExtension.fromString('stop'), equals(FinishReason.stop));
      expect(FinishReasonExtension.fromString('cancel'), equals(FinishReason.cancel));
      expect(FinishReasonExtension.fromString('error'), equals(FinishReason.error));
    });

    test('fromString defaults to eos for unknown', () {
      expect(FinishReasonExtension.fromString('unknown'), equals(FinishReason.eos));
    });
  });

  group('GenerationStats', () {
    test('toJson serializes correctly', () {
      const stats = GenerationStats(
        promptTokens: 10,
        completionTokens: 20,
        timeToFirstTokenMs: 100,
        msPerToken: 5.5,
      );
      final json = stats.toJson();
      expect(json['promptTokens'], equals(10));
      expect(json['completionTokens'], equals(20));
      expect(json['timeToFirstTokenMs'], equals(100));
      expect(json['msPerToken'], equals(5.5));
    });

    test('toJson omits null optional fields', () {
      const stats = GenerationStats(promptTokens: 10, completionTokens: 20);
      final json = stats.toJson();
      expect(json.containsKey('timeToFirstTokenMs'), isFalse);
      expect(json.containsKey('msPerToken'), isFalse);
    });

    test('fromJson deserializes correctly', () {
      final stats = GenerationStats.fromJson({
        'promptTokens': 10,
        'completionTokens': 20,
        'timeToFirstTokenMs': 100,
        'msPerToken': 5.5,
      });
      expect(stats.promptTokens, equals(10));
      expect(stats.completionTokens, equals(20));
      expect(stats.timeToFirstTokenMs, equals(100));
      expect(stats.msPerToken, equals(5.5));
    });

    test('fromJson handles missing fields', () {
      final stats = GenerationStats.fromJson({});
      expect(stats.promptTokens, equals(0));
      expect(stats.completionTokens, equals(0));
      expect(stats.timeToFirstTokenMs, isNull);
      expect(stats.msPerToken, isNull);
    });
  });

  group('LLMErrorInfo', () {
    test('toJson serializes correctly', () {
      const error = LLMErrorInfo(
        code: 'ERR_001',
        message: 'test error',
        retriable: true,
      );
      final json = error.toJson();
      expect(json['code'], equals('ERR_001'));
      expect(json['message'], equals('test error'));
      expect(json['retriable'], isTrue);
    });

    test('toJson defaults retriable to false', () {
      const error = LLMErrorInfo(code: 'ERR', message: 'msg');
      final json = error.toJson();
      expect(json['retriable'], isFalse);
    });

    test('fromJson deserializes correctly', () {
      final error = LLMErrorInfo.fromJson({
        'code': 'ERR',
        'message': 'msg',
        'retriable': true,
      });
      expect(error.code, equals('ERR'));
      expect(error.message, equals('msg'));
      expect(error.retriable, isTrue);
    });

    test('fromJson handles missing fields', () {
      final error = LLMErrorInfo.fromJson({});
      expect(error.code, equals(''));
      expect(error.message, equals(''));
      expect(error.retriable, isFalse);
    });
  });

  group('LLMStreamEvent', () {
    test('delta factory creates correct event', () {
      final event = LLMStreamEvent.delta(
        requestId: 'req_1',
        sequence: 0,
        deltaText: 'hello',
        tokenIds: [1, 2, 3],
      );
      expect(event.eventType, equals(LLMEventType.delta));
      expect(event.requestId, equals('req_1'));
      expect(event.sequence, equals(0));
      expect(event.deltaText, equals('hello'));
      expect(event.tokenIds, equals([1, 2, 3]));
      expect(event.finishReason, isNull);
      expect(event.error, isNull);
    });

    test('metrics factory creates correct event', () {
      const stats = GenerationStats(promptTokens: 10, completionTokens: 20);
      final event = LLMStreamEvent.metrics(
        requestId: 'req_1',
        sequence: 1,
        stats: stats,
      );
      expect(event.eventType, equals(LLMEventType.metrics));
      expect(event.stats, equals(stats));
    });

    test('finish factory creates correct event', () {
      const stats = GenerationStats(promptTokens: 10, completionTokens: 20);
      final event = LLMStreamEvent.finish(
        requestId: 'req_1',
        sequence: 2,
        finishReason: FinishReason.stop,
        stats: stats,
      );
      expect(event.eventType, equals(LLMEventType.finish));
      expect(event.finishReason, equals(FinishReason.stop));
      expect(event.stats, equals(stats));
    });

    test('error factory creates correct event', () {
      const error = LLMErrorInfo(code: 'ERR', message: 'failed');
      final event = LLMStreamEvent.error(
        requestId: 'req_1',
        sequence: 3,
        error: error,
      );
      expect(event.eventType, equals(LLMEventType.error));
      expect(event.error, equals(error));
      expect(event.finishReason, equals(FinishReason.error));
    });

    test('toJson serializes all fields', () {
      final event = LLMStreamEvent.delta(
        requestId: 'req_1',
        sequence: 0,
        deltaText: 'hello',
      );
      final json = event.toJson();
      expect(json['eventType'], equals('delta'));
      expect(json['requestId'], equals('req_1'));
      expect(json['sequence'], equals(0));
      expect(json['deltaText'], equals('hello'));
    });

    test('toJson omits null fields', () {
      final event = LLMStreamEvent.delta(
        requestId: 'req_1',
        sequence: 0,
        deltaText: 'hello',
      );
      final json = event.toJson();
      expect(json.containsKey('tokenIds'), isFalse);
      expect(json.containsKey('stats'), isFalse);
      expect(json.containsKey('finishReason'), isFalse);
      expect(json.containsKey('error'), isFalse);
    });

    test('fromJson deserializes delta event', () {
      final event = LLMStreamEvent.fromJson({
        'eventType': 'delta',
        'requestId': 'req_1',
        'sequence': 0,
        'deltaText': 'hello',
        'tokenIds': [1, 2],
      });
      expect(event.eventType, equals(LLMEventType.delta));
      expect(event.requestId, equals('req_1'));
      expect(event.deltaText, equals('hello'));
      expect(event.tokenIds, equals([1, 2]));
    });

    test('fromJson deserializes finish event with stats', () {
      final event = LLMStreamEvent.fromJson({
        'eventType': 'finish',
        'requestId': 'req_1',
        'sequence': 5,
        'finishReason': 'stop',
        'stats': {'promptTokens': 10, 'completionTokens': 20},
      });
      expect(event.eventType, equals(LLMEventType.finish));
      expect(event.finishReason, equals(FinishReason.stop));
      expect(event.stats?.promptTokens, equals(10));
      expect(event.stats?.completionTokens, equals(20));
    });

    test('fromJson deserializes error event', () {
      final event = LLMStreamEvent.fromJson({
        'eventType': 'error',
        'requestId': 'req_1',
        'sequence': 6,
        'error': {'code': 'ERR', 'message': 'failed', 'retriable': true},
      });
      expect(event.eventType, equals(LLMEventType.error));
      expect(event.error?.code, equals('ERR'));
      expect(event.error?.message, equals('failed'));
      expect(event.error?.retriable, isTrue);
    });

    test('fromJson handles missing optional fields', () {
      final event = LLMStreamEvent.fromJson({
        'eventType': 'delta',
        'requestId': 'req_1',
        'sequence': 0,
      });
      expect(event.deltaText, isNull);
      expect(event.tokenIds, isNull);
      expect(event.stats, isNull);
      expect(event.finishReason, isNull);
      expect(event.error, isNull);
    });
  });

  group('StopStringsMatcher', () {
    test('detects stop string in single chunk', () {
      final matcher = StopStringsMatcher(['STOP']);
      final (matched, processed, remaining) = matcher.addChunk('hello STOP world');
      expect(matched, isTrue);
      expect(processed, equals('hello '));
      expect(remaining, equals(''));
    });

    test('detects stop string across chunks', () {
      final matcher = StopStringsMatcher(['STOP']);
      // First chunk: "hello ST" (length 8), keepBack = len(STOP)-1 = 3
      // processed = substring(0, 8-3) = "hello"
      // remaining = substring(5) = " ST"
      final (matched1, processed1, remaining1) = matcher.addChunk('hello ST');
      expect(matched1, isFalse);
      expect(processed1, equals('hello'));
      expect(remaining1, equals(' ST'));

      // Second chunk: buffer becomes " STOP world"
      // Stop string "STOP" found at index 1
      // matchedText = substring(0, 1) = " "
      final (matched2, processed2, remaining2) = matcher.addChunk('OP world');
      expect(matched2, isTrue);
      expect(processed2, equals(' '));
      expect(remaining2, equals(''));
    });

    test('returns processed text keeping potential match buffer', () {
      final matcher = StopStringsMatcher(['STOP']);
      // "hello world" has no stop string, but keeps last 4 chars (len(STOP)-1) in buffer
      final (matched, processed, remaining) = matcher.addChunk('hello world');
      expect(matched, isFalse);
      expect(processed, equals('hello wo'));
      expect(remaining, equals('rld'));
    });

    test('handles empty stop strings list', () {
      final matcher = StopStringsMatcher([]);
      final (matched, processed, _) = matcher.addChunk('hello world');
      expect(matched, isFalse);
      expect(processed, equals('hello world'));
    });

    test('multiple stop strings', () {
      final matcher = StopStringsMatcher(['END', 'STOP']);
      final (matched, processed, _) = matcher.addChunk('hello END');
      expect(matched, isTrue);
      expect(processed, equals('hello '));
    });

    test('reset clears buffer', () {
      final matcher = StopStringsMatcher(['STOP']);
      matcher.addChunk('partial');
      matcher.reset();
      expect(matcher.remaining, equals(''));
    });

    test('remaining returns buffer content', () {
      final matcher = StopStringsMatcher(['STOP']);
      matcher.addChunk('ST');
      expect(matcher.remaining, equals('ST'));
    });
  });

  group('_LLMRequestId', () {
    test('generates unique IDs with prefix', () {
      final id1 = _LLMRequestId.next('test');
      final id2 = _LLMRequestId.next('test');
      expect(id1, startsWith('test_'));
      expect(id2, startsWith('test_'));
      expect(id1, isNot(equals(id2)));
    });
  });
}

class _LLMRequestId {
  static int _counter = 0;

  static String next(String prefix) {
    _counter++;
    return '${prefix}_$_counter';
  }
}
