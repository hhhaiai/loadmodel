import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/core/local_model_manager.dart';
import 'package:model_loader/runtime/model_format.dart';

void main() {
  group('LocalModelManager', () {
    late LocalModelManager manager;

    setUp(() {
      manager = LocalModelManager();
    });

    test('supportedFormats contains expected formats', () {
      expect(LocalModelManager.supportedFormats, contains('.gguf'));
      expect(LocalModelManager.supportedFormats, contains('.onnx'));
      expect(LocalModelManager.supportedFormats, contains('.safetensors'));
      expect(LocalModelManager.supportedFormats, contains('.bin'));
    });

    test('scanModels returns empty list for non-existent directory', () async {
      final models = await manager.scanModels('/non/existent/path');
      expect(models, isEmpty);
    });

    test('getFormatDescription returns correct descriptions', () {
      expect(manager.getFormatDescription(ModelFormat.gguf), contains('GGUF'));
      expect(manager.getFormatDescription(ModelFormat.onnx), contains('ONNX'));
      expect(manager.getFormatDescription(ModelFormat.safetensors), contains('SafeTensors'));
      expect(manager.getFormatDescription(ModelFormat.bin), contains('BIN'));
      expect(manager.getFormatDescription(ModelFormat.unknown), contains('未知'));
    });

    test('getRuntimeForFormat returns correct runtimes', () {
      expect(manager.getRuntimeForFormat(ModelFormat.gguf), equals('llama.cpp'));
      expect(manager.getRuntimeForFormat(ModelFormat.onnx), equals('ONNX Runtime'));
      expect(manager.getRuntimeForFormat(ModelFormat.safetensors), contains('转换'));
      expect(manager.getRuntimeForFormat(ModelFormat.unknown), contains('不支持'));
    });

    test('getSupportedTasks returns correct task lists', () {
      expect(manager.getSupportedTasks(ModelFormat.gguf), contains('LLM'));
      expect(manager.getSupportedTasks(ModelFormat.onnx), contains('Embedding'));
      expect(manager.getSupportedTasks(ModelFormat.safetensors), contains('需转换'));
      expect(manager.getSupportedTasks(ModelFormat.unknown), contains('不支持'));
    });
  });
}
