import 'package:flutter/material.dart';

import '../model_loader.dart';
import '../models/llm_model_catalog.dart';
import '../runtime/llm_runtime.dart';
import '../utils/logger.dart';

/// 设置页面
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedLLMModel = LLMModelCatalog.defaultModelId;
  String _selectedEmbeddingModel = 'bge-small';
  double _temperature = 0.7;
  int _maxTokens = 2048;
  int _contextLength = 2048;
  final TextEditingController _systemPromptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _systemPromptController.dispose();
    super.dispose();
  }

  static const Map<String, Map<String, dynamic>> embeddingModels = {
    'bge-small': {
      'name': 'BGE Small (English)',
      'size': '~90MB',
      'dimension': 384,
    },
    'bge-small-zh': {
      'name': 'BGE Small (Chinese)',
      'size': '~90MB',
      'dimension': 512,
    },
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(context, '💬 LLM 模型设置', [
            _buildDropdown(
              '模型',
              _selectedLLMModel,
              LLMModelCatalog.selectableIds,
              (value) {
                setState(() => _selectedLLMModel = value!);
              },
              (key) => LLMModelCatalog.getById(key)!.settingsDropdownLabel,
            ),
            _buildSlider(
              'Temperature',
              _temperature,
              0.0,
              2.0,
              (value) => setState(() => _temperature = value),
            ),
            _buildSlider(
              'Max Tokens',
              _maxTokens.toDouble(),
              256,
              4096,
              (value) => setState(() => _maxTokens = value.toInt()),
              divisions: 15,
              valueLabel: '$_maxTokens',
            ),
            _buildSlider(
              'Context Length',
              _contextLength.toDouble(),
              512,
              4096,
              (value) => setState(() => _contextLength = value.toInt()),
              divisions: 7,
              valueLabel: '$_contextLength',
            ),
            _buildMultilineField(
              '系统提示词',
              controller: _systemPromptController,
              hintText: '例如：你是一个简洁、准确、直接回答问题的中文助手。',
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection(context, '📊 Embedding 模型设置', [
            _buildDropdown(
              '模型',
              _selectedEmbeddingModel,
              embeddingModels.keys.toList(),
              (value) {
                setState(() => _selectedEmbeddingModel = value!);
              },
              (key) =>
                  '${embeddingModels[key]!['name']} (${embeddingModels[key]!['size']})',
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection(context, '📱 当前平台', [
            _buildInfoRow('平台', _getPlatform()),
            _buildInfoRow('LLM 运行时', _getLLMRuntime()),
            _buildInfoRow('Embedding 运行时', 'ONNX Runtime'),
          ]),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            label: const Text('保存设置'),
          ),
        ],
      ),
    );
  }

  String _getPlatform() {
    final ml = ModelLoader.instance;
    if (ml.platform.isMacOS) return 'macOS';
    if (ml.platform.isIOS) return 'iOS';
    if (ml.platform.isAndroid) return 'Android';
    if (ml.platform.isWindows) return 'Windows';
    if (ml.platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  String _getLLMRuntime() {
    return 'llama.cpp (native channel)';
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>(
    String label,
    T value,
    List<T> items,
    ValueChanged<T?> onChanged,
    String Function(T) itemLabel,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<T>(
            initialValue: value,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: items.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    int? divisions,
    String? valueLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(valueLabel ?? value.toStringAsFixed(1)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: value.toStringAsFixed(1),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildMultilineField(
    String label, {
    required TextEditingController controller,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: hintText,
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSettings() async {
    try {
      final settings = ModelLoader.instance.configManager.uiSettings;
      if (settings.isEmpty || !mounted) {
        return;
      }

      final selectedLLMModel = settings['selectedLLMModel']?.toString();
      final selectedEmbeddingModel = settings['selectedEmbeddingModel']
          ?.toString();
      final temperature = (settings['temperature'] as num?)?.toDouble();
      final maxTokens = (settings['maxTokens'] as num?)?.toInt();
      final contextLength = (settings['contextLength'] as num?)?.toInt();
      final systemPrompt = settings['systemPrompt']?.toString();

      setState(() {
        if (selectedLLMModel != null &&
            LLMModelCatalog.contains(selectedLLMModel)) {
          _selectedLLMModel = selectedLLMModel;
        }
        if (selectedEmbeddingModel != null &&
            embeddingModels.containsKey(selectedEmbeddingModel)) {
          _selectedEmbeddingModel = selectedEmbeddingModel;
        }
        if (temperature != null) {
          _temperature = temperature.clamp(0.0, 2.0);
        }
        if (maxTokens != null) {
          _maxTokens = maxTokens.clamp(256, 4096);
        }
        if (contextLength != null) {
          _contextLength = contextLength.clamp(512, 4096);
        }
        if (systemPrompt != null) {
          _systemPromptController.text = systemPrompt;
        }
      });
    } catch (e, st) {
      logger.warning('Failed to load UI settings', e, st);
    }
  }

  Future<void> _saveSettings() async {
    try {
      await ModelLoader.instance.configManager.setUISettings({
        'selectedLLMModel': _selectedLLMModel,
        'selectedEmbeddingModel': _selectedEmbeddingModel,
        'temperature': _temperature,
        'maxTokens': _maxTokens,
        'contextLength': _contextLength,
        'systemPrompt': _systemPromptController.text,
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('设置已保存')));
    } catch (e, st) {
      logger.warning('Failed to save UI settings', e, st);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
    }
  }

  Map<String, dynamic> getCurrentLLMConfig() {
    return LLMModelCatalog.getById(_selectedLLMModel)!.toSettingsConfig();
  }

  Map<String, dynamic> getCurrentEmbeddingConfig() {
    return embeddingModels[_selectedEmbeddingModel]!;
  }

  GenerationConfig getGenerationConfig() {
    return GenerationConfig(temperature: _temperature, maxTokens: _maxTokens);
  }
}
