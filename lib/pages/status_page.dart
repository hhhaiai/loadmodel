import 'package:flutter/material.dart';

import '../model_loader.dart';

/// 状态页面
class StatusPage extends StatelessWidget {
  const StatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ml = ModelLoader.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('状态'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            context,
            '📱 平台信息',
            [
              _buildRow('平台', ml.platform.name.toUpperCase()),
              _buildRow('移动端', ml.platform.isMobile ? '✅' : '❌'),
              _buildRow('桌面端', ml.platform.isDesktop ? '✅' : '❌'),
              _buildRow('量化支持', ml.platform.isDesktop ? '✅' : '❌ (仅桌面)'),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            '⚙️ 运行时状态',
            [
              _buildRow('LLM', ml.llm.isLoaded ? '✅ 已加载' : '❌ 未加载'),
              _buildRow('OCR', ml.ocr.isLoaded ? '✅ 已加载' : '❌ 未加载'),
              _buildRow('TTS', ml.tts.isLoaded ? '✅ 已加载' : '❌ 未加载'),
              _buildRow('STT', ml.stt.isLoaded ? '✅ 已加载' : '❌ 未加载'),
              _buildRow('Embedding', ml.embedding.isLoaded ? '✅ 已加载' : '❌ 未加载'),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            '📁 目录',
            [
              _buildRow('缓存', ml.config.cacheDir),
              _buildRow('自定义', ml.config.customDir),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
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

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              overflow: TextOverflow.fade,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
