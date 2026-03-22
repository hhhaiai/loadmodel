import 'dart:io';

/// 模型格式枚举
enum ModelFormat {
  /// GGUF 格式 (llama.cpp)
  gguf,

  /// ONNX 格式
  onnx,

  /// SafeTensors 格式
  safetensors,

  /// 二进制格式
  bin,

  /// 未知格式
  unknown,
}

/// 模型格式检测
extension ModelFormatExtension on String {
  ModelFormat get modelFormat {
    final lower = toLowerCase();
    if (lower.endsWith('.gguf')) return ModelFormat.gguf;
    if (lower.endsWith('.onnx')) return ModelFormat.onnx;
    if (lower.endsWith('.safetensors')) return ModelFormat.safetensors;
    if (lower.endsWith('.bin')) return ModelFormat.bin;
    return ModelFormat.unknown;
  }
}

/// 模型信息
class LocalModelInfo {
  final String id;
  final String name;
  final String path;
  final ModelFormat format;
  final int size;
  final DateTime? lastModified;

  const LocalModelInfo({
    required this.id,
    required this.name,
    required this.path,
    required this.format,
    required this.size,
    this.lastModified,
  });

  /// 从文件路径创建模型信息
  static Future<LocalModelInfo?> fromPath(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final stat = await file.stat();
      final name = filePath.split('/').last;
      final format = name.modelFormat;

      return LocalModelInfo(
        id: name.hashCode.toString(),
        name: name,
        path: filePath,
        format: format,
        size: stat.size,
        lastModified: stat.modified,
      );
    } catch (e) {
      return null;
    }
  }
}

/// 通用模型加载器接口
abstract class ModelLoaderBase {
  /// 加载模型
  Future<bool> loadModel(LocalModelInfo model);

  /// 卸载模型
  Future<void> unloadModel();

  /// 是否已加载
  bool get isLoaded;

  /// 获取模型信息
  LocalModelInfo? get loadedModel;
}

/// LLM 推理接口
abstract class LLMInference {
  /// 文本补全
  Future<String> complete(String prompt, {Map<String, dynamic>? config});

  /// 流式补全
  Stream<String> completeStream(String prompt, {Map<String, dynamic>? config});

  /// 对话
  Future<String> chat(List<Map<String, String>> messages, {Map<String, dynamic>? config});

  /// 流式对话
  Stream<String> chatStream(List<Map<String, String>> messages, {Map<String, dynamic>? config});
}

/// Embedding 推理接口
abstract class EmbeddingInference {
  /// 获取文本向量
  Future<List<double>> getEmbedding(String text);
}

/// OCR 推理接口
abstract class OCRInference {
  /// 识别图片文字
  Future<String> recognize(String imagePath);
}

/// STT 推理接口
abstract class STTInference {
  /// 识别语音
  Future<String> recognize(String audioPath);
}
