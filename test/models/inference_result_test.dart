import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/models/inference_result.dart';

void main() {
  group('OCRBlock', () {
    test('creates with required parameters', () {
      const block = OCRBlock(text: 'Hello');

      expect(block.text, equals('Hello'));
      expect(block.confidence, equals(1.0));
      expect(block.boundingBox, isNull);
    });

    test('creates with all parameters', () {
      const box = Rect(left: 10, top: 20, width: 100, height: 50);
      const block = OCRBlock(
        text: 'Hello',
        confidence: 0.95,
        boundingBox: box,
      );

      expect(block.text, equals('Hello'));
      expect(block.confidence, equals(0.95));
      expect(block.boundingBox, equals(box));
    });

    test('fromJson parses complete data', () {
      final json = {
        'text': 'Test',
        'confidence': 0.9,
        'bbox': {
          'left': 5.0,
          'top': 10.0,
          'width': 50.0,
          'height': 20.0,
        },
      };

      final block = OCRBlock.fromJson(json);

      expect(block.text, equals('Test'));
      expect(block.confidence, equals(0.9));
      expect(block.boundingBox, isNotNull);
      expect(block.boundingBox!.left, equals(5.0));
    });

    test('fromJson handles missing values with defaults', () {
      final json = <String, dynamic>{};

      final block = OCRBlock.fromJson(json);

      expect(block.text, equals(''));
      expect(block.confidence, equals(1.0));
      expect(block.boundingBox, isNull);
    });

    test('toJson produces correct output', () {
      const block = OCRBlock(text: 'Test', confidence: 0.8);
      final json = block.toJson();

      expect(json['text'], equals('Test'));
      expect(json['confidence'], equals(0.8));
      expect(json['bbox'], isNull);
    });

    test('toJson includes bounding box when present', () {
      const box = Rect(left: 1, top: 2, width: 3, height: 4);
      const block = OCRBlock(text: 'Test', boundingBox: box);
      final json = block.toJson();

      expect(json['bbox'], isNotNull);
      expect(json['bbox']['left'], equals(1));
    });
  });

  group('Rect', () {
    test('creates with required parameters', () {
      const rect = Rect(left: 10, top: 20, width: 100, height: 50);

      expect(rect.left, equals(10));
      expect(rect.top, equals(20));
      expect(rect.width, equals(100));
      expect(rect.height, equals(50));
    });

    test('fromJson parses complete data', () {
      final json = {
        'left': 5.0,
        'top': 10.0,
        'width': 50.0,
        'height': 20.0,
      };

      final rect = Rect.fromJson(json);

      expect(rect.left, equals(5.0));
      expect(rect.top, equals(10.0));
      expect(rect.width, equals(50.0));
      expect(rect.height, equals(20.0));
    });

    test('fromJson handles missing values with defaults', () {
      final json = <String, dynamic>{};

      final rect = Rect.fromJson(json);

      expect(rect.left, equals(0.0));
      expect(rect.top, equals(0.0));
      expect(rect.width, equals(0.0));
      expect(rect.height, equals(0.0));
    });

    test('toJson produces correct output', () {
      const rect = Rect(left: 1, top: 2, width: 3, height: 4);
      final json = rect.toJson();

      expect(json['left'], equals(1));
      expect(json['top'], equals(2));
      expect(json['width'], equals(3));
      expect(json['height'], equals(4));
    });
  });

  group('OCRResult', () {
    test('creates with required parameters', () {
      const result = OCRResult(
        text: 'Hello World',
        blocks: [],
      );

      expect(result.text, equals('Hello World'));
      expect(result.blocks, isEmpty);
      expect(result.averageConfidence, equals(1.0));
    });

    test('creates with all parameters', () {
      const block = OCRBlock(text: 'Test', confidence: 0.9);
      const result = OCRResult(
        text: 'Test',
        blocks: [block],
        averageConfidence: 0.85,
      );

      expect(result.blocks.length, equals(1));
      expect(result.averageConfidence, equals(0.85));
    });

    test('fromJson parses complete data', () {
      final json = {
        'text': 'Test text',
        'blocks': [
          {'text': 'Word1', 'confidence': 0.9},
          {'text': 'Word2', 'confidence': 0.8},
        ],
        'averageConfidence': 0.85,
      };

      final result = OCRResult.fromJson(json);

      expect(result.text, equals('Test text'));
      expect(result.blocks.length, equals(2));
      expect(result.averageConfidence, equals(0.85));
    });

    test('fromJson handles missing values with defaults', () {
      final json = <String, dynamic>{};

      final result = OCRResult.fromJson(json);

      expect(result.text, equals(''));
      expect(result.blocks, isEmpty);
      expect(result.averageConfidence, equals(1.0));
    });

    test('toJson produces correct output', () {
      const block = OCRBlock(text: 'Test', confidence: 0.9);
      const result = OCRResult(
        text: 'Test',
        blocks: [block],
        averageConfidence: 0.9,
      );
      final json = result.toJson();

      expect(json['text'], equals('Test'));
      expect(json['blocks'], isA<List>());
      expect(json['averageConfidence'], equals(0.9));
    });
  });

  group('STTResult', () {
    test('creates with required parameters', () {
      const result = STTResult(text: 'Hello');

      expect(result.text, equals('Hello'));
      expect(result.segments, isEmpty);
      expect(result.language, isNull);
      expect(result.confidence, equals(1.0));
    });

    test('creates with all parameters', () {
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

      expect(result.segments.length, equals(1));
      expect(result.language, equals('en'));
      expect(result.confidence, equals(0.9));
    });

    test('fromJson parses complete data', () {
      final json = {
        'text': 'Speech text',
        'segments': [
          {'start': 0.0, 'end': 1.0, 'text': 'Speech', 'confidence': 0.9},
        ],
        'language': 'en',
        'confidence': 0.85,
      };

      final result = STTResult.fromJson(json);

      expect(result.text, equals('Speech text'));
      expect(result.segments.length, equals(1));
      expect(result.language, equals('en'));
      expect(result.confidence, equals(0.85));
    });

    test('fromJson handles missing values with defaults', () {
      final json = <String, dynamic>{};

      final result = STTResult.fromJson(json);

      expect(result.text, equals(''));
      expect(result.segments, isEmpty);
      expect(result.language, isNull);
      expect(result.confidence, equals(1.0));
    });

    test('toJson produces correct output', () {
      const segment = STTSegment(start: 0, end: 1, text: 'Test');
      const result = STTResult(
        text: 'Test',
        segments: [segment],
        language: 'zh',
        confidence: 0.9,
      );
      final json = result.toJson();

      expect(json['text'], equals('Test'));
      expect(json['segments'], isA<List>());
      expect(json['language'], equals('zh'));
      expect(json['confidence'], equals(0.9));
    });
  });

  group('STTSegment', () {
    test('creates with required parameters', () {
      const segment = STTSegment(
        start: 0.0,
        end: 1.5,
        text: 'Hello',
      );

      expect(segment.start, equals(0.0));
      expect(segment.end, equals(1.5));
      expect(segment.text, equals('Hello'));
      expect(segment.confidence, equals(1.0));
    });

    test('creates with all parameters', () {
      const segment = STTSegment(
        start: 1.0,
        end: 2.5,
        text: 'World',
        confidence: 0.95,
      );

      expect(segment.confidence, equals(0.95));
    });

    test('fromJson parses complete data', () {
      final json = {
        'start': 0.5,
        'end': 1.5,
        'text': 'Test',
        'confidence': 0.9,
      };

      final segment = STTSegment.fromJson(json);

      expect(segment.start, equals(0.5));
      expect(segment.end, equals(1.5));
      expect(segment.text, equals('Test'));
      expect(segment.confidence, equals(0.9));
    });

    test('fromJson handles missing values with defaults', () {
      final json = <String, dynamic>{};

      final segment = STTSegment.fromJson(json);

      expect(segment.start, equals(0.0));
      expect(segment.end, equals(0.0));
      expect(segment.text, equals(''));
      expect(segment.confidence, equals(1.0));
    });

    test('toJson produces correct output', () {
      const segment = STTSegment(
        start: 1.0,
        end: 2.0,
        text: 'Test',
        confidence: 0.8,
      );
      final json = segment.toJson();

      expect(json['start'], equals(1.0));
      expect(json['end'], equals(2.0));
      expect(json['text'], equals('Test'));
      expect(json['confidence'], equals(0.8));
    });
  });

  group('TTSResult', () {
    test('creates with audioPath', () {
      const result = TTSResult(
        audioPath: '/path/to/audio.wav',
      );

      expect(result.audioPath, equals('/path/to/audio.wav'));
      expect(result.audioBytes, isNull);
      expect(result.duration, equals(0.0));
      expect(result.sampleRate, equals(16000));
    });

    test('creates with audioBytes', () {
      const result = TTSResult(
        audioBytes: [1, 2, 3, 4],
      );

      expect(result.audioBytes, isNotNull);
      expect(result.audioBytes!.length, equals(4));
    });

    test('creates with all parameters', () {
      const result = TTSResult(
        audioPath: '/audio.wav',
        duration: 2.5,
        sampleRate: 44100,
      );

      expect(result.audioPath, equals('/audio.wav'));
      expect(result.duration, equals(2.5));
      expect(result.sampleRate, equals(44100));
    });

    test('has default sampleRate of 16000', () {
      const result = TTSResult();
      expect(result.sampleRate, equals(16000));
    });
  });
}
