import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/runtime/ocr_runtime.dart';
import 'package:model_loader/runtime/ocr_runtime_stub.dart';
import 'package:model_loader/runtime/stt_runtime.dart';
import 'package:model_loader/runtime/stt_runtime_stub.dart';
import 'package:model_loader/runtime/tts_runtime.dart';
import 'package:model_loader/runtime/tts_runtime_stub.dart';
import 'package:model_loader/runtime/embedding_runtime.dart';
import 'package:model_loader/runtime/embedding_runtime_stub.dart';

void main() {
  group('OCRRuntimeStub', () {
    late OCRRuntimeStub stub;

    setUp(() {
      stub = OCRRuntimeStub();
    });

    test('isLoaded returns false', () {
      expect(stub.isLoaded, isFalse);
    });

    test('loadModel throws UnimplementedError', () {
      expect(
        () => stub.loadModel(const OCRConfig(modelPath: '/mock')),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('unloadModel completes without error', () async {
      await expectLater(stub.unloadModel(), completes);
    });

    test('recognize throws UnimplementedError', () {
      expect(
        () => stub.recognize('/mock/image.jpg'),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('recognizeBytes throws UnimplementedError', () {
      expect(
        () => stub.recognizeBytes(Uint8List(0)),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });

  group('STTRuntimeStub', () {
    late STTRuntimeStub stub;

    setUp(() {
      stub = STTRuntimeStub();
    });

    test('isLoaded returns false', () {
      expect(stub.isLoaded, isFalse);
    });

    test('loadModel throws UnimplementedError', () {
      expect(
        () => stub.loadModel(const STTConfig(modelPath: '/mock')),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('unloadModel completes without error', () async {
      await expectLater(stub.unloadModel(), completes);
    });

    test('recognize throws UnimplementedError', () {
      expect(
        () => stub.recognize('/mock/audio.wav'),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('recognizeBytes throws UnimplementedError', () {
      expect(
        () => stub.recognizeBytes(Uint8List(0)),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('recognizeStream throws UnimplementedError', () async {
      // The stream throws when iterated
      final stream = stub.recognizeStream(Stream.value(Uint8List(0)));
      await expectLater(
        stream.first,
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('getSupportedLanguages returns empty list', () async {
      final languages = await stub.getSupportedLanguages();
      expect(languages, isEmpty);
    });
  });

  group('TTSRuntimeStub', () {
    late TTSRuntimeStub stub;

    setUp(() {
      stub = TTSRuntimeStub();
    });

    test('isLoaded returns false', () {
      expect(stub.isLoaded, isFalse);
    });

    test('loadModel throws UnimplementedError', () {
      expect(
        () => stub.loadModel(const TTSConfig(modelPath: '/mock')),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('unloadModel completes without error', () async {
      await expectLater(stub.unloadModel(), completes);
    });

    test('synthesize throws UnimplementedError', () {
      expect(
        () => stub.synthesize('Hello'),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('synthesizeBytes throws UnimplementedError', () {
      expect(
        () => stub.synthesizeBytes('Hello'),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('getAvailableVoices returns empty list', () async {
      final voices = await stub.getAvailableVoices();
      expect(voices, isEmpty);
    });
  });

  group('EmbeddingRuntimeStub', () {
    late EmbeddingRuntimeStub stub;

    setUp(() {
      stub = EmbeddingRuntimeStub();
    });

    test('isLoaded returns false', () {
      expect(stub.isLoaded, isFalse);
    });

    test('loadModel throws UnimplementedError', () {
      expect(
        () => stub.loadModel(const EmbeddingConfig(modelPath: '/mock')),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('unloadModel completes without error', () async {
      await expectLater(stub.unloadModel(), completes);
    });

    test('getEmbedding throws UnimplementedError', () {
      expect(
        () => stub.getEmbedding('Hello'),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}
