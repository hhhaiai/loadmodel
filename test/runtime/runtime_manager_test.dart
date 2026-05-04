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

class _NotLoadedEmbeddingRuntime implements EmbeddingRuntime {
  bool unloadCalled = false;

  @override
  bool get isLoaded => false;

  @override
  Future<void> loadModel(EmbeddingConfig config) async {}

  @override
  Future<void> unloadModel() async {
    unloadCalled = true;
  }

  @override
  Future<EmbeddingResult> getEmbedding(String text) async =>
      const EmbeddingResult(embedding: [0.0], dimension: 1);
}

void main() {
  group('RuntimeManager', () {
    setUp(() async {
      // Reset RuntimeManager state before each test
      await RuntimeManager.instance.dispose();
    });

    tearDown(() async {
      // Clean up after each test
      await RuntimeManager.instance.dispose();
    });

    test('singleton returns same instance', () {
      final instance1 = RuntimeManager.instance;
      final instance2 = RuntimeManager.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('instance exists', () {
      final manager = RuntimeManager.instance;
      expect(manager, isA<RuntimeManager>());
    });

    group('stub runtimes', () {
      late RuntimeManager manager;

      setUp(() async {
        await RuntimeManager.instance.dispose();
        // Init without custom runtimes to get stub implementations
        await RuntimeManager.instance.init();
        manager = RuntimeManager.instance;
      });

      tearDown(() async {
        await RuntimeManager.instance.dispose();
      });

      group('_LLMRuntimeStub', () {
        test('isLoaded returns false', () {
          expect(manager.llm!.isLoaded, false);
        });

        test('loadModel throws UnimplementedError', () async {
          await expectLater(
            manager.llm!.loadModel(const LLMConfig(modelPath: '/test', contextLength: 2048)),
            throwsA(isA<UnimplementedError>()),
          );
        });

        test('unloadModel completes without error', () async {
          await expectLater(manager.llm!.unloadModel(), completes);
        });

        test('complete throws UnimplementedError', () async {
          await expectLater(
            manager.llm!.complete('test'),
            throwsA(isA<UnimplementedError>()),
          );
        });

        test('completeStream throws UnimplementedError', () async {
          await expectLater(
            manager.llm!.completeStream('test').first,
            throwsA(isA<UnimplementedError>()),
          );
        });

        test('chat throws UnimplementedError', () async {
          await expectLater(
            manager.llm!.chat([ChatMessage.user('test')]),
            throwsA(isA<UnimplementedError>()),
          );
        });

        test('chatStream throws UnimplementedError', () async {
          await expectLater(
            manager.llm!.chatStream([ChatMessage.user('test')]).first,
            throwsA(isA<UnimplementedError>()),
          );
        });
      });

      group('_OCRRuntimeStub', () {
        test('isLoaded returns false', () {
          expect(manager.ocr!.isLoaded, false);
        });

        test('loadModel throws UnimplementedError', () async {
          await expectLater(
            manager.ocr!.loadModel(const OCRConfig(modelPath: '/test')),
            throwsA(isA<UnimplementedError>()),
          );
        });

        test('unloadModel completes without error', () async {
          await expectLater(manager.ocr!.unloadModel(), completes);
        });

        test('recognize throws UnimplementedError', () async {
          await expectLater(
            manager.ocr!.recognize('/test/image.png'),
            throwsA(isA<UnimplementedError>()),
          );
        });

        test('recognizeBytes throws UnimplementedError', () async {
          await expectLater(
            manager.ocr!.recognizeBytes(Uint8List(0)),
            throwsA(isA<UnimplementedError>()),
          );
        });
      });

      group('_TTSRuntimeStub', () {
        test('isLoaded returns false', () {
          expect(manager.tts!.isLoaded, false);
        });

        test('loadModel throws UnimplementedError', () async {
          await expectLater(
            manager.tts!.loadModel(const TTSConfig(modelPath: '/test')),
            throwsA(isA<UnimplementedError>()),
          );
        });

        test('unloadModel completes without error', () async {
          await expectLater(manager.tts!.unloadModel(), completes);
        });

        test('synthesize throws UnimplementedError', () async {
          await expectLater(
            manager.tts!.synthesize('hello'),
            throwsA(isA<UnimplementedError>()),
          );
        });

        test('synthesizeBytes throws UnimplementedError', () async {
          await expectLater(
            manager.tts!.synthesizeBytes('hello'),
            throwsA(isA<UnimplementedError>()),
          );
        });

        test('getAvailableVoices returns empty list', () async {
          final voices = await manager.tts!.getAvailableVoices();
          expect(voices, isEmpty);
        });
      });

      group('_STTRuntimeStub', () {
        test('isLoaded returns false', () {
          expect(manager.stt!.isLoaded, false);
        });

        test('loadModel throws UnimplementedError', () async {
          await expectLater(
            manager.stt!.loadModel(const STTConfig(modelPath: '/test')),
            throwsA(isA<UnimplementedError>()),
          );
        });

        test('unloadModel completes without error', () async {
          await expectLater(manager.stt!.unloadModel(), completes);
        });

        test('recognize throws UnimplementedError', () async {
          await expectLater(
            manager.stt!.recognize('/test/audio.wav'),
            throwsA(isA<UnimplementedError>()),
          );
        });

        test('recognizeBytes throws UnimplementedError', () async {
          await expectLater(
            manager.stt!.recognizeBytes(Uint8List(0)),
            throwsA(isA<UnimplementedError>()),
          );
        });

        test('recognizeStream throws UnimplementedError', () async {
          await expectLater(
            manager.stt!.recognizeStream(Stream.value(Uint8List(0))).first,
            throwsA(isA<UnimplementedError>()),
          );
        });

        test('getSupportedLanguages returns empty list', () async {
          final languages = await manager.stt!.getSupportedLanguages();
          expect(languages, isEmpty);
        });
      });

      group('_EmbeddingRuntimeStub', () {
        test('isLoaded returns false', () {
          expect(manager.embedding!.isLoaded, false);
        });

        test('loadModel throws UnimplementedError', () async {
          await expectLater(
            manager.embedding!.loadModel(const EmbeddingConfig(modelPath: '/test')),
            throwsA(isA<UnimplementedError>()),
          );
        });

        test('unloadModel completes without error', () async {
          await expectLater(manager.embedding!.unloadModel(), completes);
        });

        test('getEmbedding throws UnimplementedError', () async {
          await expectLater(
            manager.embedding!.getEmbedding('test'),
            throwsA(isA<UnimplementedError>()),
          );
        });
      });
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

    test('dispose unloads loaded runtimes and resets initialized flag', () async {
      final manager = RuntimeManager.instance;

      // Init with loaded runtimes that track unload calls
      final trackingLLM = _LoadedTrackingLLMRuntime();
      final trackingOCR = _LoadedTrackingOCRRuntime();
      final trackingTTS = _LoadedTrackingTTSRuntime();
      final trackingSTT = _LoadedTrackingSTTRuntime();
      final trackingEmbedding = _LoadedTrackingEmbeddingRuntime();

      await manager.init(
        customLLM: trackingLLM,
        customOCR: trackingOCR,
        customTTS: trackingTTS,
        customSTT: trackingSTT,
        customEmbedding: trackingEmbedding,
      );

      await manager.dispose();

      expect(trackingLLM.unloadCalled, true);
      expect(trackingOCR.unloadCalled, true);
      expect(trackingTTS.unloadCalled, true);
      expect(trackingSTT.unloadCalled, true);
      expect(trackingEmbedding.unloadCalled, true);
    });

    test('dispose skips unload when runtime isLoaded is false', () async {
      final manager = RuntimeManager.instance;

      // Init with not-loaded runtimes
      final notLoadedLLM = _NotLoadedLLMRuntime();
      final notLoadedOCR = _NotLoadedOCRRuntime();
      final notLoadedTTS = _NotLoadedTTSRuntime();
      final notLoadedSTT = _NotLoadedSTTRuntime();
      final notLoadedEmbedding = _NotLoadedEmbeddingRuntime();

      await manager.init(
        customLLM: notLoadedLLM,
        customOCR: notLoadedOCR,
        customTTS: notLoadedTTS,
        customSTT: notLoadedSTT,
        customEmbedding: notLoadedEmbedding,
      );

      await manager.dispose();

      expect(notLoadedLLM.unloadCalled, false);
      expect(notLoadedOCR.unloadCalled, false);
      expect(notLoadedTTS.unloadCalled, false);
      expect(notLoadedSTT.unloadCalled, false);
      expect(notLoadedEmbedding.unloadCalled, false);
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

// Tracking runtimes that record whether unload was called
class _LoadedTrackingLLMRuntime implements LLMRuntime {
  bool unloadCalled = false;

  @override
  LLMModelInfo? get loadedModel => const LLMModelInfo(name: 'test', path: '/test');

  @override
  bool get isLoaded => true;

  @override
  Future<void> loadModel(LLMConfig config) async {}

  @override
  Future<void> unloadModel() async {
    unloadCalled = true;
  }

  @override
  Future<String> complete(String prompt, {GenerationConfig? config}) async => '';

  @override
  Stream<String> completeStream(String prompt, {GenerationConfig? config}) async* {}

  @override
  Future<String> chat(List<ChatMessage> messages, {GenerationConfig? config}) async => '';

  @override
  Stream<String> chatStream(List<ChatMessage> messages, {GenerationConfig? config}) async* {}
}

class _LoadedTrackingOCRRuntime implements OCRRuntime {
  bool unloadCalled = false;

  @override
  bool get isLoaded => true;

  @override
  Future<void> loadModel(OCRConfig config) async {}

  @override
  Future<void> unloadModel() async {
    unloadCalled = true;
  }

  @override
  Future<OCRResult> recognize(String imagePath, {OCRParams? params}) async =>
      const OCRResult(text: '', blocks: []);

  @override
  Future<OCRResult> recognizeBytes(Uint8List imageBytes, {OCRParams? params}) async =>
      const OCRResult(text: '', blocks: []);
}

class _LoadedTrackingTTSRuntime implements TTSRuntime {
  bool unloadCalled = false;

  @override
  bool get isLoaded => true;

  @override
  Future<void> loadModel(TTSConfig config) async {}

  @override
  Future<void> unloadModel() async {
    unloadCalled = true;
  }

  @override
  Future<String> synthesize(String text, {TTSParams? params, String? outputPath}) async => '';

  @override
  Future<Uint8List> synthesizeBytes(String text, {TTSParams? params}) async => Uint8List(0);

  @override
  Future<List<String>> getAvailableVoices() async => [];
}

class _LoadedTrackingSTTRuntime implements STTRuntime {
  bool unloadCalled = false;

  @override
  bool get isLoaded => true;

  @override
  Future<void> loadModel(STTConfig config) async {}

  @override
  Future<void> unloadModel() async {
    unloadCalled = true;
  }

  @override
  Future<STTResult> recognize(String audioPath, {STTParams? params}) async =>
      const STTResult(text: '');

  @override
  Future<STTResult> recognizeBytes(Uint8List audioBytes, {STTParams? params}) async =>
      const STTResult(text: '');

  @override
  Stream<STTResult> recognizeStream(Stream<Uint8List> audioStream, {STTParams? params}) async* {}

  @override
  Future<List<String>> getSupportedLanguages() async => [];
}

class _LoadedTrackingEmbeddingRuntime implements EmbeddingRuntime {
  bool unloadCalled = false;

  @override
  bool get isLoaded => true;

  @override
  Future<void> loadModel(EmbeddingConfig config) async {}

  @override
  Future<void> unloadModel() async {
    unloadCalled = true;
  }

  @override
  Future<EmbeddingResult> getEmbedding(String text) async =>
      const EmbeddingResult(embedding: [0.0], dimension: 1);
}

// Not-loaded runtimes that should skip unload in dispose
class _NotLoadedLLMRuntime implements LLMRuntime {
  bool unloadCalled = false;

  @override
  LLMModelInfo? get loadedModel => null;

  @override
  bool get isLoaded => false;

  @override
  Future<void> loadModel(LLMConfig config) async {}

  @override
  Future<void> unloadModel() async {
    unloadCalled = true;
  }

  @override
  Future<String> complete(String prompt, {GenerationConfig? config}) async => '';

  @override
  Stream<String> completeStream(String prompt, {GenerationConfig? config}) async* {}

  @override
  Future<String> chat(List<ChatMessage> messages, {GenerationConfig? config}) async => '';

  @override
  Stream<String> chatStream(List<ChatMessage> messages, {GenerationConfig? config}) async* {}
}

class _NotLoadedOCRRuntime implements OCRRuntime {
  bool unloadCalled = false;

  @override
  bool get isLoaded => false;

  @override
  Future<void> loadModel(OCRConfig config) async {}

  @override
  Future<void> unloadModel() async {
    unloadCalled = true;
  }

  @override
  Future<OCRResult> recognize(String imagePath, {OCRParams? params}) async =>
      const OCRResult(text: '', blocks: []);

  @override
  Future<OCRResult> recognizeBytes(Uint8List imageBytes, {OCRParams? params}) async =>
      const OCRResult(text: '', blocks: []);
}

class _NotLoadedTTSRuntime implements TTSRuntime {
  bool unloadCalled = false;

  @override
  bool get isLoaded => false;

  @override
  Future<void> loadModel(TTSConfig config) async {}

  @override
  Future<void> unloadModel() async {
    unloadCalled = true;
  }

  @override
  Future<String> synthesize(String text, {TTSParams? params, String? outputPath}) async => '';

  @override
  Future<Uint8List> synthesizeBytes(String text, {TTSParams? params}) async => Uint8List(0);

  @override
  Future<List<String>> getAvailableVoices() async => [];
}

class _NotLoadedSTTRuntime implements STTRuntime {
  bool unloadCalled = false;

  @override
  bool get isLoaded => false;

  @override
  Future<void> loadModel(STTConfig config) async {}

  @override
  Future<void> unloadModel() async {
    unloadCalled = true;
  }

  @override
  Future<STTResult> recognize(String audioPath, {STTParams? params}) async =>
      const STTResult(text: '');

  @override
  Future<STTResult> recognizeBytes(Uint8List audioBytes, {STTParams? params}) async =>
      const STTResult(text: '');

  @override
  Stream<STTResult> recognizeStream(Stream<Uint8List> audioStream, {STTParams? params}) async* {}

  @override
  Future<List<String>> getSupportedLanguages() async => [];
}
