import 'content_block.dart';

enum ConversationEntryRole {
  user,
  assistant,
  status,
  error,
}

class ConversationEntry {
  final ConversationEntryRole role;
  final String text;
  final bool isComplete;
  final List<ContentBlock>? contentBlocks;

  const ConversationEntry({
    required this.role,
    required this.text,
    this.isComplete = true,
    this.contentBlocks,
  });

  bool get hasStructuredContent =>
      contentBlocks != null && contentBlocks!.isNotEmpty;

  ConversationEntry copyWith({
    ConversationEntryRole? role,
    String? text,
    bool? isComplete,
    List<ContentBlock>? contentBlocks,
  }) {
    return ConversationEntry(
      role: role ?? this.role,
      text: text ?? this.text,
      isComplete: isComplete ?? this.isComplete,
      contentBlocks: contentBlocks ?? this.contentBlocks,
    );
  }
}
