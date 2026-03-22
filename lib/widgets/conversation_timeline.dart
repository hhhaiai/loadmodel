import 'package:flutter/material.dart';

import '../models/conversation_entry.dart';

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
                  : SelectableText(entry.text.isEmpty ? '...' : entry.text),
            ),
          ),
        );
      },
    );
  }
}
