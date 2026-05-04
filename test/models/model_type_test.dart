import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/models/model_type.dart';

void main() {
  group('ModelType', () {
    test('all types are defined', () {
      expect(ModelType.values, containsAll([
        ModelType.llm,
        ModelType.embedding,
        ModelType.ocr,
        ModelType.tts,
        ModelType.stt,
        ModelType.classification,
        ModelType.custom,
      ]));
    });

    test('displayName returns correct Chinese names', () {
      expect(ModelType.llm.displayName, equals('对话模型'));
      expect(ModelType.embedding.displayName, equals('向量模型'));
      expect(ModelType.ocr.displayName, equals('OCR识别'));
      expect(ModelType.tts.displayName, equals('文字转语音'));
      expect(ModelType.stt.displayName, equals('语音转文字'));
      expect(ModelType.classification.displayName, equals('分类模型'));
      expect(ModelType.custom.displayName, equals('自定义模型'));
    });

    test('name returns correct identifiers', () {
      expect(ModelType.llm.name, equals('llm'));
      expect(ModelType.embedding.name, equals('embedding'));
      expect(ModelType.ocr.name, equals('ocr'));
      expect(ModelType.tts.name, equals('tts'));
      expect(ModelType.stt.name, equals('stt'));
      expect(ModelType.classification.name, equals('classification'));
      expect(ModelType.custom.name, equals('custom'));
    });

    test('fromString parses valid values', () {
      expect(ModelTypeExtension.fromString('llm'), equals(ModelType.llm));
      expect(ModelTypeExtension.fromString('embedding'), equals(ModelType.embedding));
      expect(ModelTypeExtension.fromString('ocr'), equals(ModelType.ocr));
      expect(ModelTypeExtension.fromString('tts'), equals(ModelType.tts));
      expect(ModelTypeExtension.fromString('stt'), equals(ModelType.stt));
      expect(ModelTypeExtension.fromString('classification'), equals(ModelType.classification));
      expect(ModelTypeExtension.fromString('custom'), equals(ModelType.custom));
    });

    test('fromString returns custom for unknown values', () {
      expect(ModelTypeExtension.fromString('unknown'), equals(ModelType.custom));
      expect(ModelTypeExtension.fromString(''), equals(ModelType.custom));
    });

    test('fromString is case insensitive', () {
      expect(ModelTypeExtension.fromString('LLM'), equals(ModelType.llm));
      expect(ModelTypeExtension.fromString('Embedding'), equals(ModelType.embedding));
      expect(ModelTypeExtension.fromString('OCR'), equals(ModelType.ocr));
      expect(ModelTypeExtension.fromString('TTS'), equals(ModelType.tts));
      expect(ModelTypeExtension.fromString('STT'), equals(ModelType.stt));
    });
  });
}
