import 'package:flutter/material.dart';

import '../models/conversation_entry.dart';
import '../models/content_block.dart';

class ConversationTimeline extends StatelessWidget {
  const ConversationTimeline({
    super.key,
    required this.entries,
    this.emptyStateText = '在这里开始一段新的对话',
  });

  final List<ConversationEntry> entries;
  final String emptyStateText;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(child: Text(emptyStateText));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isUser = entry.role == ConversationEntryRole.user;
        final isError = entry.role == ConversationEntryRole.error;
        final isStatus = entry.role == ConversationEntryRole.status;
        final isGeneratingAssistant =
            entry.role == ConversationEntryRole.assistant &&
            !entry.isComplete &&
            entry.text.trim().isEmpty;
        final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
        final backgroundColor = isUser
            ? Theme.of(context).colorScheme.primaryContainer
            : isError
            ? Colors.red.shade100
            : isStatus
            ? Colors.grey.shade200
            : Colors.grey.shade100;

        return Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: isGeneratingAssistant
                  ? const Text('正在生成中...')
                  : entry.hasStructuredContent
                      ? _buildContentBlocks(context, entry.contentBlocks!)
                      : SelectableText(entry.text.isEmpty ? '...' : entry.text),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContentBlocks(
    BuildContext context,
    List<ContentBlock> blocks,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((block) {
        if (block is TextBlock) {
          return SelectableText(block.text);
        } else if (block is ErrorBlock) {
          final prefix = block.code != null ? '[${block.code}] ' : '';
          return Text(
            '$prefix${block.message}',
            style: TextStyle(color: Colors.red.shade700),
          );
        } else if (block is StatusBlock) {
          return Text(
            block.message,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          );
        } else if (block is EmbeddingBlock) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Embedding 维度: ${block.dimension}'),
              Text(
                '前5值: ${block.preview.take(5).map((v) => v.toStringAsFixed(4)).join(", ")}',
              ),
            ],
          );
        } else if (block is OCRBlockDisplay) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (block.imageBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    block.imageBytes!,
                    height: 150,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 150,
                      alignment: Alignment.center,
                      child: Text(
                        '图片加载失败',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SelectableText(
                block.text,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                '置信度: ${(block.confidence * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          );
        } else if (block is MetricBlock) {
          return Text(
            '${block.label}: ${block.value}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          );
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }
}
