import 'package:flutter/material.dart';

import '../model_loader.dart';
import '../models/model_registry.dart';
import '../models/model_type.dart';

/// 模型列表页面
class ModelsPage extends StatelessWidget {
  const ModelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ml = ModelLoader.instance;
    final models = ml.getSupportedModels();

    return Scaffold(
      appBar: AppBar(
        title: const Text('支持的模型'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: models.length,
        itemBuilder: (context, index) {
          final model = models[index];
          return Card(
            child: ListTile(
              leading: _getIcon(model.type),
              title: Text(model.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('格式: ${model.formats.join(", ")}'),
                  Text('最低内存: ${model.capability.minMemoryMB}MB'),
                ],
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showModelInfo(context, model);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _getIcon(ModelType type) {
    switch (type) {
      case ModelType.llm:
        return const Text('💬', style: TextStyle(fontSize: 24));
      case ModelType.embedding:
        return const Text('📊', style: TextStyle(fontSize: 24));
      case ModelType.stt:
        return const Text('🎤', style: TextStyle(fontSize: 24));
      case ModelType.tts:
        return const Text('🔊', style: TextStyle(fontSize: 24));
      case ModelType.ocr:
        return const Text('📷', style: TextStyle(fontSize: 24));
      case ModelType.classification:
        return const Text('🏷️', style: TextStyle(fontSize: 24));
      case ModelType.custom:
        return const Text('📦', style: TextStyle(fontSize: 24));
    }
  }

  void _showModelInfo(BuildContext context, ModelDefinition model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(model.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('类型: ${model.type.displayName}'),
            Text('格式: ${model.formats.join(", ")}'),
            const SizedBox(height: 8),
            Text('最低内存: ${model.capability.minMemoryMB}MB'),
            Text('推荐内存: ${model.capability.recommendedMemoryMB}MB'),
            const SizedBox(height: 8),
            Text('支持量化: ${model.capability.supportsQuantization ? "✅" : "❌"}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
