import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/models/inference_result.dart';
import 'package:model_loader/runtime/ocr_runtime.dart';
import 'package:model_loader/runtime/stt_runtime.dart';
import 'package:model_loader/runtime/tts_runtime.dart';
import 'package:model_loader/runtime/embedding_runtime.dart';

void main() {
  group('OCRParams', () {
    test('creates with default values', () {
      const params = OCRParams();
      expect(params.language, isNull);
      expect(params.detectDirection, isNull);
      expect(params.angleThreshold, isNull);
    });

    test('creates with custom values', () {
      const params = OCRParams(
        language: 'eng',
        detectDirection: true,
        angleThreshold: 0.5,
      );
      expect(params.language, 'eng');
      expect(params.detectDirection, true);
      expect(params.angleThreshold, 0.5);
    });

    test('toJson excludes null values', () {
      const params = OCRParams(language: 'eng');
      final json = params.toJson();
      expect(json.containsKey('language'), isTrue);
      expect(json.containsKey('detectDirection'), isFalse);
      expect(json.containsKey('angle_threshold'), isFalse);
    });

    test('toJson includes all values when provided', () {
      const params = OCRParams(
        language: 'chi_sim',
        detectDirection: false,
        angleThreshold: 0.8,
      );
      final json = params.toJson();
      expect(json['language'], 'chi_sim');
      expect(json['detect_direction'], false);
      expect(json['angle_threshold'], 0.8);
    });
  });

  group('OCRConfig', () {
    test('creates with required parameters', () {
      const config = OCRConfig(modelPath: '/path/to/model.onnx');
      expect(config.modelPath, '/path/to/model.onnx');
      expect(config.language, 'eng+chi_sim');
      expect(config.config, isNull);
    });

    test('creates with all parameters', () {
      const config = OCRConfig(
        modelPath: '/path/to/model.onnx',
        language: 'eng',
        config: {'threshold': 0.5},
      );
      expect(config.language, 'eng');
      expect(config.config, isNotNull);
    });

    test('toJson produces correct output', () {
      const config = OCRConfig(
        modelPath: '/path/to/model.onnx',
        language: 'chi_sim',
        config: {'threshold': 0.5},
      );
      final json = config.toJson();
      expect(json['modelPath'], '/path/to/model.onnx');
      expect(json['language'], 'chi_sim');
      expect(json['config'], {'threshold': 0.5});
    });
  });

  group('STTParams', () {
    test('creates with default values', () {
      const params = STTParams();
      expect(params.language, isNull);
      expect(params.translate, isNull);
      expect(params.timestamps, isNull);
      expect(params.multilingual, isNull);
      expect(params.chunkSize, isNull);
    });

    test('creates with custom values', () {
      const params = STTParams(
        language: 'en',
        translate: true,
        timestamps: true,
        multilingual: false,
        chunkSize: 1024,
      );
      expect(params.language, 'en');
      expect(params.translate, true);
      expect(params.timestamps, true);
      expect(params.multilingual, false);
      expect(params.chunkSize, 1024);
    });

    test('toJson excludes null values', () {
      const params = STTParams(language: 'zh');
      final json = params.toJson();
      expect(json.containsKey('language'), isTrue);
      expect(json.containsKey('translate'), isFalse);
    });

    test('toJson includes all values when provided', () {
      const params = STTParams(
        language: 'zh',
        translate: true,
        timestamps: false,
        multilingual: true,
        chunkSize: 2048,
      );
      final json = params.toJson();
      expect(json['language'], 'zh');
      expect(json['translate'], true);
      expect(json['timestamps'], false);
      expect(json['multilingual'], true);
      expect(json['chunk_size'], 2048);
    });
  });

  group('STTConfig', () {
    test('creates with required parameters', () {
      const config = STTConfig(modelPath: '/path/to/model.onnx');
      expect(config.modelPath, '/path/to/model.onnx');
      expect(config.language, 'auto');
      expect(config.sampleRate, 16000);
      expect(config.config, isNull);
    });

    test('creates with all parameters', () {
      const config = STTConfig(
        modelPath: '/path/to/model.onnx',
        language: 'zh',
        sampleRate: 44100,
        config: {'beam_size': 10},
      );
      expect(config.language, 'zh');
      expect(config.sampleRate, 44100);
      expect(config.config, isNotNull);
    });

    test('toJson produces correct output', () {
      const config = STTConfig(
        modelPath: '/path/to/model.onnx',
        language: 'en',
        sampleRate: 22050,
      );
      final json = config.toJson();
      expect(json['modelPath'], '/path/to/model.onnx');
      expect(json['language'], 'en');
      expect(json['sampleRate'], 22050);
    });
  });

  group('TTSParams', () {
    test('creates with default values', () {
      const params = TTSParams();
      expect(params.speed, isNull);
      expect(params.pitch, isNull);
      expect(params.volume, isNull);
      expect(params.voice, isNull);
      expect(params.format, isNull);
    });

    test('creates with custom values', () {
      const params = TTSParams(
        speed: 1.5,
        pitch: 0.8,
        volume: 0.9,
        voice: 'female',
        format: 'mp3',
      );
      expect(params.speed, 1.5);
      expect(params.pitch, 0.8);
      expect(params.volume, 0.9);
      expect(params.voice, 'female');
      expect(params.format, 'mp3');
    });

    test('toJson excludes null values', () {
      const params = TTSParams(speed: 1.0);
      final json = params.toJson();
      expect(json.containsKey('speed'), isTrue);
      expect(json.containsKey('pitch'), isFalse);
    });

    test('toJson includes all values when provided', () {
      const params = TTSParams(
        speed: 1.2,
        pitch: 1.0,
        volume: 0.8,
        voice: 'male',
        format: 'wav',
      );
      final json = params.toJson();
      expect(json['speed'], 1.2);
      expect(json['pitch'], 1.0);
      expect(json['volume'], 0.8);
      expect(json['voice'], 'male');
      expect(json['format'], 'wav');
    });
  });

  group('TTSConfig', () {
    test('creates with required parameters', () {
      const config = TTSConfig(modelPath: '/path/to/model.onnx');
      expect(config.modelPath, '/path/to/model.onnx');
      expect(config.language, isNull);
      expect(config.sampleRate, 22050);
      expect(config.config, isNull);
    });

    test('creates with all parameters', () {
      const config = TTSConfig(
        modelPath: '/path/to/model.onnx',
        language: 'zh',
        sampleRate: 44100,
        config: {'vocoder': 'hifigan'},
      );
      expect(config.language, 'zh');
      expect(config.sampleRate, 44100);
      expect(config.config, isNotNull);
    });

    test('toJson produces correct output', () {
      const config = TTSConfig(
        modelPath: '/path/to/model.onnx',
        language: 'en',
        sampleRate: 48000,
      );
      final json = config.toJson();
      expect(json['modelPath'], '/path/to/model.onnx');
      expect(json['language'], 'en');
      expect(json['sampleRate'], 48000);
    });
  });

  group('EmbeddingConfig', () {
    test('creates with required parameters', () {
      const config = EmbeddingConfig(modelPath: '/path/to/model.onnx');
      expect(config.modelPath, '/path/to/model.onnx');
      expect(config.tokenizerPath, isNull);
      expect(config.maxLength, 512);
    });

    test('creates with all parameters', () {
      const config = EmbeddingConfig(
        modelPath: '/path/to/model.onnx',
        tokenizerPath: '/path/to/tokenizer',
        maxLength: 256,
      );
      expect(config.tokenizerPath, '/path/to/tokenizer');
      expect(config.maxLength, 256);
    });

    test('toJson produces correct output', () {
      const config = EmbeddingConfig(
        modelPath: '/path/to/model.onnx',
        tokenizerPath: '/path/to/tokenizer',
        maxLength: 128,
      );
      final json = config.toJson();
      expect(json['modelPath'], '/path/to/model.onnx');
      expect(json['tokenizerPath'], '/path/to/tokenizer');
      expect(json['maxLength'], 128);
    });
  });

  group('EmbeddingResult', () {
    test('creates with required parameters', () {
      const result = EmbeddingResult(embedding: [0.1, 0.2, 0.3], dimension: 3);
      expect(result.embedding, [0.1, 0.2, 0.3]);
      expect(result.dimension, 3);
    });

    test('fromJson parses complete data', () {
      final json = {'embedding': [0.1, 0.2], 'dimension': 2};
      final result = EmbeddingResult.fromJson(json);
      expect(result.embedding, [0.1, 0.2]);
      expect(result.dimension, 2);
    });

    test('fromJson handles empty list', () {
      final json = {'embedding': <dynamic>[], 'dimension': 0};
      final result = EmbeddingResult.fromJson(json);
      expect(result.embedding, isEmpty);
      expect(result.dimension, 0);
    });
  });

  group('OCRResult', () {
    test('creates with required parameters', () {
      const result = OCRResult(text: 'Hello', blocks: []);
      expect(result.text, 'Hello');
      expect(result.blocks, isEmpty);
      expect(result.averageConfidence, 1.0);
    });

    test('creates with all parameters', () {
      const result = OCRResult(
        text: 'Hello',
        blocks: [],
        averageConfidence: 0.9,
      );
      expect(result.averageConfidence, 0.9);
    });

    test('toJson produces correct output', () {
      const result = OCRResult(
        text: 'Test',
        blocks: [],
        averageConfidence: 0.85,
      );
      final json = result.toJson();
      expect(json['text'], 'Test');
      expect(json['averageConfidence'], 0.85);
    });

    test('fromJson parses complete data', () {
      final json = {'text': 'Hello', 'blocks': [], 'averageConfidence': 0.9};
      final result = OCRResult.fromJson(json);
      expect(result.text, 'Hello');
      expect(result.averageConfidence, 0.9);
    });

    test('fromJson handles missing values with defaults', () {
      final json = <String, dynamic>{};
      final result = OCRResult.fromJson(json);
      expect(result.text, '');
      expect(result.averageConfidence, 1.0);
    });
  });

  group('OCRBlock', () {
    test('creates with required parameters', () {
      const block = OCRBlock(text: 'Hello');
      expect(block.text, 'Hello');
      expect(block.confidence, 1.0);
      expect(block.boundingBox, isNull);
    });

    test('creates with all parameters', () {
      const block = OCRBlock(
        text: 'Hello',
        confidence: 0.95,
      );
      expect(block.confidence, 0.95);
    });
  });

  group('STTResult', () {
    test('creates with required parameters', () {
      const result = STTResult(text: 'Hello');
      expect(result.text, 'Hello');
      expect(result.segments, isEmpty);
      expect(result.language, isNull);
      expect(result.confidence, 1.0);
    });

    test('creates with all parameters', () {
      const result = STTResult(
        text: 'Hello',
        segments: [],
        language: 'en',
        confidence: 0.95,
      );
      expect(result.language, 'en');
      expect(result.confidence, 0.95);
    });

    test('toJson produces correct output', () {
      const result = STTResult(
        text: 'Test',
        language: 'zh',
        confidence: 0.9,
      );
      final json = result.toJson();
      expect(json['text'], 'Test');
      expect(json['language'], 'zh');
      expect(json['confidence'], 0.9);
    });

    test('fromJson parses complete data', () {
      final json = {'text': 'Hello', 'language': 'en', 'confidence': 0.9};
      final result = STTResult.fromJson(json);
      expect(result.text, 'Hello');
      expect(result.language, 'en');
      expect(result.confidence, 0.9);
    });

    test('fromJson handles missing values with defaults', () {
      final json = <String, dynamic>{};
      final result = STTResult.fromJson(json);
      expect(result.text, '');
      expect(result.confidence, 1.0);
    });
  });

  group('STTSegment', () {
    test('creates with required parameters', () {
      const segment = STTSegment(text: 'Hello', start: 0.0, end: 1.0);
      expect(segment.text, 'Hello');
      expect(segment.start, 0.0);
      expect(segment.end, 1.0);
    });

    test('creates with all parameters', () {
      const segment = STTSegment(
        text: 'Hello',
        start: 0.0,
        end: 1.0,
        confidence: 0.95,
      );
      expect(segment.confidence, 0.95);
    });

    test('fromJson parses complete data', () {
      final json = {'text': 'Hello', 'start': 0.0, 'end': 1.0, 'confidence': 0.95};
      final segment = STTSegment.fromJson(json);
      expect(segment.text, 'Hello');
      expect(segment.confidence, 0.95);
    });
  });

  group('TTSResult', () {
    test('creates with audioPath', () {
      final result = TTSResult(audioPath: '/path/to/audio.wav');
      expect(result.audioPath, '/path/to/audio.wav');
      expect(result.audioBytes, isNull);
    });

    test('creates with audioBytes', () {
      final result = TTSResult(audioBytes: Uint8List.fromList([1, 2, 3]));
      expect(result.audioBytes, isNotNull);
      expect(result.audioPath, isNull);
    });

    test('creates with all parameters', () {
      final result = TTSResult(
        audioPath: '/path/to/audio.wav',
        sampleRate: 44100,
      );
      expect(result.sampleRate, 44100);
    });
  });
}
