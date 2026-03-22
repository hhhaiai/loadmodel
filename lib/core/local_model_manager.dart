import 'dart:io';
import '../runtime/model_format.dart';
import '../utils/logger.dart';

/// 本地模型管理器
/// 自动检测模型格式并选择合适的运行时
class LocalModelManager {
  /// 支持的模型格式
  static const supportedFormats = ['.gguf', '.onnx', '.safetensors', '.bin'];

  /// 扫描目录中的模型文件
  Future<List<LocalModelInfo>> scanModels(String directoryPath) async {
    final models = <LocalModelInfo>[];
    final directory = Directory(directoryPath);

    if (!await directory.exists()) {
      logger.warning('Model directory does not exist: $directoryPath');
      return models;
    }

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        final path = entity.path;
        final ext = path.toLowerCase();

        // 检查是否是支持的格式
        final isSupported = supportedFormats.any((format) => ext.endsWith(format));
        if (isSupported) {
          final modelInfo = await LocalModelInfo.fromPath(path);
          if (modelInfo != null && modelInfo.format != ModelFormat.unknown) {
            models.add(modelInfo);
          }
        }
      }
    }

    logger.info('Found ${models.length} models in $directoryPath');
    return models;
  }

  /// 获取模型格式的描述
  String getFormatDescription(ModelFormat format) {
    switch (format) {
      case ModelFormat.gguf:
        return 'GGUF (llama.cpp) - 大语言模型';
      case ModelFormat.onnx:
        return 'ONNX - 可用于推理任务';
      case ModelFormat.safetensors:
        return 'SafeTensors - PyTorch 格式';
      case ModelFormat.bin:
        return 'BIN - 原始二进制格式';
      case ModelFormat.unknown:
        return '未知格式';
    }
  }

  /// 获取格式对应的运行时类型
  String getRuntimeForFormat(ModelFormat format) {
    switch (format) {
      case ModelFormat.gguf:
        return 'llama.cpp';
      case ModelFormat.onnx:
        return 'ONNX Runtime';
      case ModelFormat.safetensors:
        return '需转换格式';
      case ModelFormat.bin:
        return '需分析内容';
      case ModelFormat.unknown:
        return '不支持';
    }
  }

  /// 根据格式判断支持的任务类型
  List<String> getSupportedTasks(ModelFormat format) {
    switch (format) {
      case ModelFormat.gguf:
        return ['LLM', 'Embedding'];
      case ModelFormat.onnx:
        return ['Embedding', 'OCR', 'STT', 'LLM(部分)'];
      case ModelFormat.safetensors:
        return ['需转换'];
      case ModelFormat.bin:
        return ['需分析'];
      case ModelFormat.unknown:
        return ['不支持'];
    }
  }
}
