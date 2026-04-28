class LLMModelOption {
  const LLMModelOption({
    required this.id,
    required this.name,
    required this.sizeLabel,
    required this.quantization,
    required this.minMemoryMB,
    this.assetPath,
  });

  final String id;
  final String name;
  final String sizeLabel;
  final String quantization;
  final int minMemoryMB;
  final String? assetPath;

  bool get isBundled => assetPath != null;

  String get loadDropdownLabel => '$name ($quantization)';

  String get settingsDropdownLabel => '$name ($sizeLabel)';

  String get successName => quantization == '未知' ? name : '$name $quantization';

  Map<String, dynamic> toSettingsConfig() {
    return {
      'name': name,
      'size': sizeLabel,
      'quantization': quantization,
      'asset': assetPath,
      'minMemory': minMemoryMB,
    };
  }
}

class LLMModelCatalog {
  static const String defaultModelId = 'tinyllama';
  static const String customModelId = 'custom';

  static const List<String> bundledIds = <String>[
    'tinyllama',
    'qwen-0.5b',
    'qwen-1.5b',
    'qwen-3.5-0.8b-q8_0',
  ];

  static const List<String> selectableIds = <String>[
    ...bundledIds,
    customModelId,
  ];

  static const Map<String, LLMModelOption> options = <String, LLMModelOption>{
    'tinyllama': LLMModelOption(
      id: 'tinyllama',
      name: 'TinyLlama 1.1B',
      sizeLabel: '638MB',
      quantization: 'Q4_K_M',
      assetPath: 'assets/models/tinyllama/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
      minMemoryMB: 1024,
    ),
    'qwen-0.5b': LLMModelOption(
      id: 'qwen-0.5b',
      name: 'Qwen2.5 0.5B',
      sizeLabel: '~600MB',
      quantization: 'Q4_0',
      assetPath: 'assets/models/qwen-1.5b/qwen2.5-0.5b-instruct-q4_0.gguf',
      minMemoryMB: 1024,
    ),
    'qwen-1.5b': LLMModelOption(
      id: 'qwen-1.5b',
      name: 'Qwen2.5 1.5B',
      sizeLabel: '~1.2GB',
      quantization: 'Q4_0',
      assetPath: 'assets/models/qwen-1.5b/qwen2.5-1.5b-instruct-q4_0.gguf',
      minMemoryMB: 2048,
    ),
    'qwen-3.5-0.8b-q8_0': LLMModelOption(
      id: 'qwen-3.5-0.8b-q8_0',
      name: 'Qwen3.5 0.8B',
      sizeLabel: '~1.0GB',
      quantization: 'Q8_0',
      assetPath: 'assets/models/qwen-3.5-0.8b/Qwen3.5-0.8B-Q8_0.gguf',
      minMemoryMB: 2048,
    ),
    customModelId: LLMModelOption(
      id: customModelId,
      name: '自定义模型',
      sizeLabel: '请选择文件',
      quantization: '未知',
      minMemoryMB: 2048,
    ),
  };

  static bool contains(String id) => options.containsKey(id);

  static LLMModelOption? getById(String id) => options[id];
}
