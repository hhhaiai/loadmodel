import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final projectRoot = Directory.current.path;
  final pubspecFile = File('$projectRoot/pubspec.yaml');

  const requiredLocalAssetPaths = <String>[
    'assets/models/bge-small/model.onnx',
    'assets/models/bge-small/tokenizer.json',
    'assets/models/bge-small/tokenizer_config.json',
    'assets/models/bge-small/vocab.txt',
    'assets/models/tinyllama/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
    'assets/models/tinyllama/model_config.json',
    'assets/models/qwen-1.5b/qwen2.5-0.5b-instruct-q4_0.gguf',
    'assets/models/qwen-1.5b/qwen2.5-0.5b-config.json',
    'assets/models/qwen-1.5b/qwen2.5-1.5b-instruct-q4_0.gguf',
    'assets/models/qwen-1.5b/qwen2.5-1.5b-config.json',
    'assets/models/qwen-3.5-0.8b/Qwen3.5-0.8B-Q8_0.gguf',
    'assets/models/qwen-3.5-0.8b/model_config.json',
    'assets/models/whisper/model.onnx',
    'assets/models/whisper/model_config.json',
    'assets/models/ocr/model.onnx',
    'assets/models/ocr/model_config.json',
  ];

  group('Local bundled assets contract', () {
    test('all required local model assets exist in repository', () {
      for (final relativePath in requiredLocalAssetPaths) {
        final file = File('$projectRoot/$relativePath');
        expect(file.existsSync(), isTrue, reason: 'missing local asset: $relativePath');
      }
    });

    test('all required local model assets are declared in pubspec', () {
      expect(pubspecFile.existsSync(), isTrue);
      final pubspecText = pubspecFile.readAsStringSync();

      for (final relativePath in requiredLocalAssetPaths) {
        expect(pubspecText, contains('- $relativePath'));
      }
    });
  });
}
