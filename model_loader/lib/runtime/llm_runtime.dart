/// Chat 消息角色
enum ChatRole {
  system,
  user,
  assistant,
}

extension ChatRoleExtension on ChatRole {
  String get name {
    switch (this) {
      case ChatRole.system:
        return 'system';
      case ChatRole.user:
        return 'user';
      case ChatRole.assistant:
        return 'assistant';
    }
  }

  static ChatRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'system':
        return ChatRole.system;
      case 'user':
        return ChatRole.user;
      case 'assistant':
        return ChatRole.assistant;
      default:
        return ChatRole.user;
    }
  }
}

/// Chat 消息
class ChatMessage {
  final ChatRole role;
  final String content;

  const ChatMessage({
    required this.role,
    required this.content,
  });

  Map<String, dynamic> toJson() {
    return {
      'role': role.name,
      'content': content,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: ChatRoleExtension.fromString(json['role'] ?? 'user'),
      content: json['content'] ?? '',
    );
  }

  /// 创建用户消息
  factory ChatMessage.user(String content) {
    return ChatMessage(role: ChatRole.user, content: content);
  }

  /// 创建系统消息
  factory ChatMessage.system(String content) {
    return ChatMessage(role: ChatRole.system, content: content);
  }

  /// 创建助手消息
  factory ChatMessage.assistant(String content) {
    return ChatMessage(role: ChatRole.assistant, content: content);
  }
}

/// LLM 生成配置
class GenerationConfig {
  /// 温度 (0.0 - 2.0)
  final double? temperature;

  /// Top-P 采样
  final double? topP;

  /// 最大生成 token 数
  final int? maxTokens;

  /// 停止字符串
  final List<String>? stopStrings;

  /// 是否流式输出
  final bool? stream;

  /// Top-K 采样
  final int? topK;

  /// 重复惩罚
  final double? repeatPenalty;

  const GenerationConfig({
    this.temperature,
    this.topP,
    this.maxTokens,
    this.stopStrings,
    this.stream,
    this.topK,
    this.repeatPenalty,
  });

  Map<String, dynamic> toJson() {
    return {
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (stopStrings != null) 'stop_strings': stopStrings,
      if (stream != null) 'stream': stream,
      if (topK != null) 'top_k': topK,
      if (repeatPenalty != null) 'repeat_penalty': repeatPenalty,
    };
  }

  /// 默认配置
  static const GenerationConfig defaultConfig = GenerationConfig(
    temperature: 0.7,
    topP: 0.9,
    maxTokens: 2048,
    stream: false,
  );
}

/// LLM 模型信息
class LLMModelInfo {
  /// 模型名称
  final String name;

  /// 模型路径
  final String path;

  /// 上下文长度
  final int contextLength;

  /// 模型参数大小 (如 7B, 3B)
  final String? parameterSize;

  /// 量化等级
  final String? quantization;

  /// Vocabulary 大小
  final int? vocabSize;

  /// 使用的硬件
  final String? hardware;

  const LLMModelInfo({
    required this.name,
    required this.path,
    this.contextLength = 4096,
    this.parameterSize,
    this.quantization,
    this.vocabSize,
    this.hardware,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'contextLength': contextLength,
      'parameterSize': parameterSize,
      'quantization': quantization,
      'vocabSize': vocabSize,
      'hardware': hardware,
    };
  }
}

/// LLM 配置
class LLMConfig {
  /// 模型文件路径
  final String modelPath;

  /// 上下文长度
  final int contextLength;

  /// 最大生成 token 数
  final int maxTokens;

  /// 温度
  final double temperature;

  /// Top-P
  final double topP;

  /// GPU 层数 (桌面端)
  final int? gpuLayers;

  /// 分词器路径 (可选)
  final String? tokenizerPath;

  /// 线程数 (桌面端)
  final int? threads;

  /// 是否使用 GPU
  final bool useGpu;

  const LLMConfig({
    required this.modelPath,
    this.contextLength = 4096,
    this.maxTokens = 2048,
    this.temperature = 0.7,
    this.topP = 0.9,
    this.gpuLayers,
    this.tokenizerPath,
    this.threads,
    this.useGpu = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'modelPath': modelPath,
      'contextLength': contextLength,
      'maxTokens': maxTokens,
      'temperature': temperature,
      'topP': topP,
      'gpuLayers': gpuLayers,
      'tokenizerPath': tokenizerPath,
      'threads': threads,
      'useGpu': useGpu,
    };
  }
}

/// LLM 运行时接口
abstract class LLMRuntime {
  /// 加载模型
  Future<void> loadModel(LLMConfig config);

  /// 卸载模型
  Future<void> unloadModel();

  /// 文本补全
  Future<String> complete(
    String prompt, {
    GenerationConfig? config,
  });

  /// 流式输出
  Stream<String> completeStream(
    String prompt, {
    GenerationConfig? config,
  });

  /// 对话
  Future<String> chat(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  });

  /// 流式对话
  Stream<String> chatStream(
    List<ChatMessage> messages, {
    GenerationConfig? config,
  });

  /// 获取已加载模型信息
  LLMModelInfo? get loadedModel;

  /// 是否已加载
  bool get isLoaded;
}
