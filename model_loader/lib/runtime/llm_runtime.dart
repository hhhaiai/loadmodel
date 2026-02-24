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
/// Reference: CLAUDE.md Section 5
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

  /// 随机种子 (Section 5.1)
  final int? seed;

  /// Batch size (Section 5.1)
  final int? batchSize;

  /// Threads (Section 5.1)
  final int? threads;

  const GenerationConfig({
    this.temperature,
    this.topP,
    this.maxTokens,
    this.stopStrings,
    this.stream,
    this.topK,
    this.repeatPenalty,
    this.seed,
    this.batchSize,
    this.threads,
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
      if (seed != null) 'seed': seed,
      if (batchSize != null) 'batch_size': batchSize,
      if (threads != null) 'threads': threads,
    };
  }

  /// Default configuration
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

// ============================================================
// LLM Streaming Events (Section 5)
// ============================================================

/// Event types for streaming (Section 5.2)
enum LLMEventType {
  /// Incremental text delta
  delta,

  /// Metrics update
  metrics,

  /// Generation finished
  finish,

  /// Error occurred
  error,
}

extension LLMEventTypeExtension on LLMEventType {
  String get name {
    switch (this) {
      case LLMEventType.delta:
        return 'delta';
      case LLMEventType.metrics:
        return 'metrics';
      case LLMEventType.finish:
        return 'finish';
      case LLMEventType.error:
        return 'error';
    }
  }

  static LLMEventType fromString(String value) {
    switch (value) {
      case 'delta':
        return LLMEventType.delta;
      case 'metrics':
        return LLMEventType.metrics;
      case 'finish':
        return LLMEventType.finish;
      case 'error':
        return LLMEventType.error;
      default:
        return LLMEventType.delta;
    }
  }
}

/// Finish reasons (Section 5.2)
enum FinishReason {
  /// End of sequence
  eos,

  /// Max length reached
  length,

  /// Stop string matched
  stop,

  /// Cancelled
  cancel,

  /// Error
  error,
}

extension FinishReasonExtension on FinishReason {
  String get name {
    switch (this) {
      case FinishReason.eos:
        return 'eos';
      case FinishReason.length:
        return 'length';
      case FinishReason.stop:
        return 'stop';
      case FinishReason.cancel:
        return 'cancel';
      case FinishReason.error:
        return 'error';
    }
  }

  static FinishReason fromString(String value) {
    switch (value) {
      case 'eos':
        return FinishReason.eos;
      case 'length':
        return FinishReason.length;
      case 'stop':
        return FinishReason.stop;
      case 'cancel':
        return FinishReason.cancel;
      case 'error':
        return FinishReason.error;
      default:
        return FinishReason.eos;
    }
  }
}

/// Generation stats (Section 5.2, 5.4)
class GenerationStats {
  /// Number of prompt tokens
  final int promptTokens;

  /// Number of completion tokens
  final int completionTokens;

  /// Time to first token in ms
  final int? timeToFirstTokenMs;

  /// Average ms per token
  final double? msPerToken;

  const GenerationStats({
    required this.promptTokens,
    required this.completionTokens,
    this.timeToFirstTokenMs,
    this.msPerToken,
  });

  Map<String, dynamic> toJson() {
    return {
      'promptTokens': promptTokens,
      'completionTokens': completionTokens,
      if (timeToFirstTokenMs != null) 'timeToFirstTokenMs': timeToFirstTokenMs,
      if (msPerToken != null) 'msPerToken': msPerToken,
    };
  }

  factory GenerationStats.fromJson(Map<String, dynamic> json) {
    return GenerationStats(
      promptTokens: json['promptTokens'] ?? 0,
      completionTokens: json['completionTokens'] ?? 0,
      timeToFirstTokenMs: json['timeToFirstTokenMs'],
      msPerToken: json['msPerToken']?.toDouble(),
    );
  }
}

/// Error info for streaming events
class LLMErrorInfo {
  /// Error code
  final String code;

  /// Error message
  final String message;

  /// Whether error is retriable
  final bool retriable;

  const LLMErrorInfo({
    required this.code,
    required this.message,
    this.retriable = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      'retriable': retriable,
    };
  }

  factory LLMErrorInfo.fromJson(Map<String, dynamic> json) {
    return LLMErrorInfo(
      code: json['code'] ?? '',
      message: json['message'] ?? '',
      retriable: json['retriable'] ?? false,
    );
  }
}

/// Streaming event (matches CLAUDE.md Section 5.2)
class LLMStreamEvent {
  /// Event type
  final LLMEventType eventType;

  /// Request ID (stable throughout request)
  final String requestId;

  /// Sequence number (strictly increasing)
  final int sequence;

  /// Delta text (for delta events)
  final String? deltaText;

  /// Token IDs (for delta events)
  final List<int>? tokenIds;

  /// Generation stats (for metrics/finish events)
  final GenerationStats? stats;

  /// Finish reason (for finish events)
  final FinishReason? finishReason;

  /// Error info (for error events)
  final LLMErrorInfo? error;

  const LLMStreamEvent({
    required this.eventType,
    required this.requestId,
    required this.sequence,
    this.deltaText,
    this.tokenIds,
    this.stats,
    this.finishReason,
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {
      'eventType': eventType.name,
      'requestId': requestId,
      'sequence': sequence,
      if (deltaText != null) 'deltaText': deltaText,
      if (tokenIds != null) 'tokenIds': tokenIds,
      if (stats != null) 'stats': stats!.toJson(),
      if (finishReason != null) 'finishReason': finishReason!.name,
      if (error != null) 'error': error!.toJson(),
    };
  }

  factory LLMStreamEvent.fromJson(Map<String, dynamic> json) {
    return LLMStreamEvent(
      eventType: LLMEventTypeExtension.fromString(json['eventType'] ?? 'delta'),
      requestId: json['requestId'] ?? '',
      sequence: json['sequence'] ?? 0,
      deltaText: json['deltaText'],
      tokenIds: json['tokenIds'] != null
          ? List<int>.from(json['tokenIds'])
          : null,
      stats: json['stats'] != null
          ? GenerationStats.fromJson(json['stats'])
          : null,
      finishReason: json['finishReason'] != null
          ? FinishReasonExtension.fromString(json['finishReason'])
          : null,
      error: json['error'] != null
          ? LLMErrorInfo.fromJson(json['error'])
          : null,
    );
  }

  /// Create delta event
  factory LLMStreamEvent.delta({
    required String requestId,
    required int sequence,
    required String deltaText,
    List<int>? tokenIds,
  }) {
    return LLMStreamEvent(
      eventType: LLMEventType.delta,
      requestId: requestId,
      sequence: sequence,
      deltaText: deltaText,
      tokenIds: tokenIds,
    );
  }

  /// Create metrics event
  factory LLMStreamEvent.metrics({
    required String requestId,
    required int sequence,
    required GenerationStats stats,
  }) {
    return LLMStreamEvent(
      eventType: LLMEventType.metrics,
      requestId: requestId,
      sequence: sequence,
      stats: stats,
    );
  }

  /// Create finish event
  factory LLMStreamEvent.finish({
    required String requestId,
    required int sequence,
    required FinishReason finishReason,
    required GenerationStats stats,
  }) {
    return LLMStreamEvent(
      eventType: LLMEventType.finish,
      requestId: requestId,
      sequence: sequence,
      finishReason: finishReason,
      stats: stats,
    );
  }

  /// Create error event
  factory LLMStreamEvent.error({
    required String requestId,
    required int sequence,
    required LLMErrorInfo error,
  }) {
    return LLMStreamEvent(
      eventType: LLMEventType.error,
      requestId: requestId,
      sequence: sequence,
      error: error,
      finishReason: FinishReason.error,
    );
  }
}

/// Non-streaming result (matches CLAUDE.md Section 5.4)
class LLMResult {
  /// Complete generated text
  final String text;

  /// Finish reason
  final FinishReason finishReason;

  /// Generation stats
  final GenerationStats stats;

  const LLMResult({
    required this.text,
    required this.finishReason,
    required this.stats,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'finishReason': finishReason.name,
      'stats': stats.toJson(),
    };
  }

  factory LLMResult.fromJson(Map<String, dynamic> json) {
    return LLMResult(
      text: json['text'] ?? '',
      finishReason: FinishReasonExtension.fromString(json['finishReason'] ?? 'stop'),
      stats: GenerationStats.fromJson(json['stats'] ?? {}),
    );
  }
}

/// Stop strings matcher (Section 5.3)
/// Handles cross-chunk matching
class StopStringsMatcher {
  final List<String> stopStrings;
  final StringBuffer _buffer = StringBuffer();

  StopStringsMatcher(this.stopStrings);

  /// Add text chunk and check for stop strings
  /// Returns: (matched, processedText, remainingBuffer)
  (bool, String, String) addChunk(String chunk) {
    _buffer.write(chunk);
    final text = _buffer.toString();

    // Check each stop string
    for (final stop in stopStrings) {
      final index = text.indexOf(stop);
      if (index != -1) {
        // Found stop string
        final matchedText = text.substring(0, index);
        _buffer.clear();
        return (true, matchedText, '');
      }
    }

    // No match, return all but last characters to allow cross-chunk matching
    // Keep last N-1 characters for potential match in next chunk
    int keepBack = 0;
    for (final stop in stopStrings) {
      if (stop.length > keepBack) {
        keepBack = stop.length - 1;
      }
    }

    if (text.length <= keepBack) {
      return (false, '', text);
    }

    final processed = text.substring(0, text.length - keepBack);
    final remaining = text.substring(text.length - keepBack);
    _buffer.clear();
    _buffer.write(remaining);

    return (false, processed, remaining);
  }

  /// Get remaining buffer content
  String get remaining => _buffer.toString();

  /// Clear buffer
  void reset() {
    _buffer.clear();
  }
}
