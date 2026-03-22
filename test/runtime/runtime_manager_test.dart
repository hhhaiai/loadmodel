import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/models/inference_result.dart';
import 'package:model_loader/runtime/llm_runtime.dart';
import 'package:model_loader/runtime/ocr_runtime.dart';
import 'package:model_loader/runtime/stt_runtime.dart';
import 'package:model_loader/runtime/tts_runtime.dart';
import 'package:model_loader/runtime/embedding_runtime.dart';
import 'package:model_loader/runtime/runtime_manager.dart';

/// Mock implementations for testing
class MockLLMRuntime implements LLMRuntime {
  bool _loaded = false;
  @override
  LLMModelInfo? get loadedModel => _loaded ? const LLMModelInfo(name: 'mock', path: '/mock') : null;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> loadModel(LLMConfig config) async {
    _loaded = true;
  }

  @override
  Future<void> unloadModel() async {
    _loaded = false;
  }

  @override
  Future<String> complete(String prompt, {GenerationConfig? config}) async => 'mock response';

  @override
  Stream<String> completeStream(String prompt, {GenerationConfig? config}) async* {
    yield 'mock ';
    yield 'response';
  }

  @override
  Future<String> chat(List<ChatMessage> messages, {GenerationConfig? config}) async => 'mock chat';

  @override
  Stream<String> chatStream(List<ChatMessage> messages, {GenerationConfig? config}) async* {
    yield 'mock ';
    yield 'chat';
  }
}

class MockOCRRuntime implements OCRRuntime {
  bool _loaded = false;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> loadModel(OCRConfig config) async {
    _loaded = true;
  }

  @override
  Future<void> unloadModel() async {
    _loaded = false;
  }

  @override
  Future<OCRResult> recognize(String imagePath, {OCRParams? params}) async {
    return const OCRResult(text: 'mock ocr result', blocks: []);
  }

  @override
  Future<OCRResult> recognizeBytes(Uint8List imageBytes, {OCRParams? params}) async {
    return const OCRResult(text: 'mock ocr bytes', blocks: []);
  }
}

class MockTTSRuntime implements TTSRuntime {
  bool _loaded = false;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> loadModel(TTSConfig config) async {
    _loaded = true;
  }

  @override
  Future<void> unloadModel() async {
    _loaded = false;
  }

  @override
  Future<String> synthesize(String text, {TTSParams? params, String? outputPath}) async {
    return '/mock/tts.wav';
  }

  @override
  Future<Uint8List> synthesizeBytes(String text, {TTSParams? params}) async {
    return Uint8List(0);
  }

  @override
  Future<List<String>> getAvailableVoices() async {
    return ['mock-voice-1', 'mock-voice-2'];
  }
}

class MockSTTRuntime implements STTRuntime {
  bool _loaded = false;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> loadModel(STTConfig config) async {
    _loaded = true;
  }

  @override
  Future<void> unloadModel() async {
    _loaded = false;
  }

  @override
  Future<STTResult> recognize(String audioPath, {STTParams? params}) async {
    return const STTResult(text: 'mock stt result');
  }

  @override
  Future<STTResult> recognizeBytes(Uint8List audioBytes, {STTParams? params}) async {
    return const STTResult(text: 'mock stt bytes');
  }

  @override
  Stream<STTResult> recognizeStream(Stream<Uint8List> audioStream, {STTParams? params}) async* {
    yield const STTResult(text: 'stream result');
  }

  @override
  Future<List<String>> getSupportedLanguages() async {
    return ['en', 'zh'];
  }
}

class MockEmbeddingRuntime implements EmbeddingRuntime {
  bool _loaded = false;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> loadModel(EmbeddingConfig config) async {
    _loaded = true;
  }

  @override
  Future<void> unloadModel() async {
    _loaded = false;
  }

  @override
  Future<EmbeddingResult> getEmbedding(String text) async {
    return const EmbeddingResult(embedding: [0.1, 0.2, 0.3], dimension: 3);
  }
}

void main() {
  group('RuntimeManager', () {
    test('singleton returns same instance', () {
      final instance1 = RuntimeManager.instance;
      final instance2 = RuntimeManager.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('instance exists', () {
      final manager = RuntimeManager.instance;
      expect(manager, isA<RuntimeManager>());
    });

    test('init with custom runtimes works', () async {
      final manager = RuntimeManager.instance;
      final mockLLM = MockLLMRuntime();
      final mockOCR = MockOCRRuntime();
      final mockTTS = MockTTSRuntime();
      final mockSTT = MockSTTRuntime();
      final mockEmbedding = MockEmbeddingRuntime();

      await manager.init(
        customLLM: mockLLM,
        customOCR: mockOCR,
        customTTS: mockTTS,
        customSTT: mockSTT,
        customEmbedding: mockEmbedding,
      );

      expect(manager.llm, isA<MockLLMRuntime>());
      expect(manager.ocr, isA<MockOCRRuntime>());
      expect(manager.tts, isA<MockTTSRuntime>());
      expect(manager.stt, isA<MockSTTRuntime>());
      expect(manager.embedding, isA<MockEmbeddingRuntime>());
    });

    test('init twice does not reinitialize', () async {
      final manager = RuntimeManager.instance;

      await manager.init(customLLM: MockLLMRuntime());
      final firstLLM = manager.llm;
      await manager.init(customLLM: MockLLMRuntime());
      final secondLLM = manager.llm;

      // Should be the same instance because second init is a no-op
      expect(identical(firstLLM, secondLLM), isTrue);
    });

    test('dispose handles runtime errors gracefully', () async {
      final manager = RuntimeManager.instance;

      // Create runtimes that throw on unload
      final throwingOCR = _ThrowingOCRRuntime();
      final throwingTTS = _ThrowingTTSRuntime();
      final throwingSTT = _ThrowingSTTRuntime();
      final throwingEmbedding = _ThrowingEmbeddingRuntime();

      // Re-init with throwing runtimes
      await manager.init(
        customLLM: MockLLMRuntime(),
        customOCR: throwingOCR,
        customTTS: throwingTTS,
        customSTT: throwingSTT,
        customEmbedding: throwingEmbedding,
      );

      // Should not throw
      await expectLater(manager.dispose(), completes);
    });
  });
}

class _ThrowingOCRRuntime implements OCRRuntime {
  @override
  bool get isLoaded => true;

  @override
  Future<void> loadModel(OCRConfig config) async => throw Exception('load error');

  @override
  Future<void> unloadModel() async => throw Exception('unload error');

  @override
  Future<OCRResult> recognize(String imagePath, {OCRParams? params}) async => throw Exception();

  @override
  Future<OCRResult> recognizeBytes(Uint8List imageBytes, {OCRParams? params}) async => throw Exception();
}

class _ThrowingTTSRuntime implements TTSRuntime {
  @override
  bool get isLoaded => true;

  @override
  Future<void> loadModel(TTSConfig config) async => throw Exception();

  @override
  Future<void> unloadModel() async => throw Exception();

  @override
  Future<String> synthesize(String text, {TTSParams? params, String? outputPath}) async => throw Exception();

  @override
  Future<Uint8List> synthesizeBytes(String text, {TTSParams? params}) async => throw Exception();

  @override
  Future<List<String>> getAvailableVoices() async => throw Exception();
}

class _ThrowingSTTRuntime implements STTRuntime {
  @override
  bool get isLoaded => true;

  @override
  Future<void> loadModel(STTConfig config) async => throw Exception();

  @override
  Future<void> unloadModel() async => throw Exception();

  @override
  Future<STTResult> recognize(String audioPath, {STTParams? params}) async => throw Exception();

  @override
  Future<STTResult> recognizeBytes(Uint8List audioBytes, {STTParams? params}) async => throw Exception();

  @override
  Stream<STTResult> recognizeStream(Stream<Uint8List> audioStream, {STTParams? params}) async* {
    throw Exception();
  }

  @override
  Future<List<String>> getSupportedLanguages() async => throw Exception();
}

class _ThrowingEmbeddingRuntime implements EmbeddingRuntime {
  @override
  bool get isLoaded => true;

  @override
  Future<void> loadModel(EmbeddingConfig config) async => throw Exception();

  @override
  Future<void> unloadModel() async => throw Exception();

  @override
  Future<EmbeddingResult> getEmbedding(String text) async => throw Exception();
}
