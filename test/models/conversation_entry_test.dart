import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/models/content_block.dart';
import 'package:model_loader/models/conversation_entry.dart';

void main() {
  group('ConversationEntry', () {
    test('creates with required parameters', () {
      const entry = ConversationEntry(
        role: ConversationEntryRole.user,
        text: 'Hello',
      );
      expect(entry.role, ConversationEntryRole.user);
      expect(entry.text, 'Hello');
      expect(entry.isComplete, isTrue);
    });

    test('creates with all optional parameters', () {
      const entry = ConversationEntry(
        role: ConversationEntryRole.assistant,
        text: 'Hi there',
        isComplete: false,
      );
      expect(entry.text, 'Hi there');
      expect(entry.isComplete, isFalse);
    });

    test('copyWith creates new instance with updated values', () {
      const original = ConversationEntry(
        role: ConversationEntryRole.user,
        text: 'Hello',
      );
      final updated = original.copyWith(text: 'Updated');
      expect(updated.text, 'Updated');
      expect(updated.role, ConversationEntryRole.user);
      expect(original.text, 'Hello');
    });

    test('copyWith preserves unchanged values', () {
      const original = ConversationEntry(
        role: ConversationEntryRole.assistant,
        text: 'Hello',
        isComplete: false,
      );
      final updated = original.copyWith(isComplete: true);
      expect(updated.isComplete, isTrue);
      expect(updated.text, 'Hello');
      expect(updated.role, ConversationEntryRole.assistant);
    });
  });

  group('ConversationEntryRole', () {
    test('has all expected values', () {
      expect(ConversationEntryRole.values, contains(ConversationEntryRole.user));
      expect(ConversationEntryRole.values, contains(ConversationEntryRole.assistant));
      expect(ConversationEntryRole.values, contains(ConversationEntryRole.status));
      expect(ConversationEntryRole.values, contains(ConversationEntryRole.error));
    });

    test('name returns correct string', () {
      expect(ConversationEntryRole.user.name, equals('user'));
      expect(ConversationEntryRole.assistant.name, equals('assistant'));
      expect(ConversationEntryRole.status.name, equals('status'));
      expect(ConversationEntryRole.error.name, equals('error'));
    });
  });

  group('ConversationEntry contentBlocks', () {
    test('contentBlocks defaults to null', () {
      const entry = ConversationEntry(
        role: ConversationEntryRole.user,
        text: 'Hello',
      );
      expect(entry.contentBlocks, isNull);
    });

    test('hasStructuredContent is false when contentBlocks is null', () {
      const entry = ConversationEntry(
        role: ConversationEntryRole.user,
        text: 'Hello',
      );
      expect(entry.hasStructuredContent, isFalse);
    });

    test('hasStructuredContent is false when contentBlocks is empty', () {
      const entry = ConversationEntry(
        role: ConversationEntryRole.user,
        text: 'Hello',
        contentBlocks: [],
      );
      expect(entry.hasStructuredContent, isFalse);
    });

    test('hasStructuredContent is true when contentBlocks is non-empty', () {
      const entry = ConversationEntry(
        role: ConversationEntryRole.assistant,
        text: '',
        contentBlocks: [TextBlock('result')],
      );
      expect(entry.hasStructuredContent, isTrue);
    });

    test('copyWith preserves contentBlocks when not overridden', () {
      const blocks = [TextBlock('hello'), MetricBlock('label', 'value')];
      const original = ConversationEntry(
        role: ConversationEntryRole.assistant,
        text: '',
        contentBlocks: blocks,
      );
      final updated = original.copyWith(isComplete: true);
      expect(updated.contentBlocks, same(blocks));
    });

    test('copyWith replaces contentBlocks when overridden', () {
      const original = ConversationEntry(
        role: ConversationEntryRole.assistant,
        text: '',
        contentBlocks: [TextBlock('old')],
      );
      const newBlocks = [TextBlock('new')];
      final updated = original.copyWith(contentBlocks: newBlocks);
      expect(updated.contentBlocks, newBlocks);
      expect(updated.contentBlocks!.first, isA<TextBlock>());
    });
  });
}
