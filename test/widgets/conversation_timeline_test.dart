import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/models/conversation_entry.dart';
import 'package:model_loader/models/content_block.dart';
import 'package:model_loader/widgets/conversation_timeline.dart';

void main() {
  Future<void> pumpTimeline(
    WidgetTester tester,
    List<ConversationEntry> entries, {
    String emptyStateText = '在这里开始一段新的对话',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationTimeline(
            entries: entries,
            emptyStateText: emptyStateText,
          ),
        ),
      ),
    );
  }

  group('ConversationTimeline', () {
    testWidgets('shows empty state text when entries is empty', (
      tester,
    ) async {
      await pumpTimeline(tester, []);
      expect(find.text('在这里开始一段新的对话'), findsOneWidget);
    });

    testWidgets('shows custom empty state text', (tester) async {
      await pumpTimeline(tester, [], emptyStateText: '没有消息');
      expect(find.text('没有消息'), findsOneWidget);
    });

    testWidgets('renders user message aligned right', (tester) async {
      await pumpTimeline(tester, [
        const ConversationEntry(role: ConversationEntryRole.user, text: 'Hi'),
      ]);
      expect(find.text('Hi'), findsOneWidget);
      final align = tester.widget<Align>(find.byType(Align));
      expect(align.alignment, Alignment.centerRight);
    });

    testWidgets('renders assistant message aligned left', (tester) async {
      await pumpTimeline(tester, [
        const ConversationEntry(
          role: ConversationEntryRole.assistant,
          text: 'Hello',
        ),
      ]);
      expect(find.text('Hello'), findsOneWidget);
      final align = tester.widget<Align>(find.byType(Align));
      expect(align.alignment, Alignment.centerLeft);
    });

    testWidgets('shows "正在生成中..." for incomplete empty assistant', (
      tester,
    ) async {
      await pumpTimeline(tester, [
        const ConversationEntry(
          role: ConversationEntryRole.assistant,
          text: '',
          isComplete: false,
        ),
      ]);
      expect(find.text('正在生成中...'), findsOneWidget);
    });

    testWidgets('shows error styling for error entries', (tester) async {
      await pumpTimeline(tester, [
        const ConversationEntry(
          role: ConversationEntryRole.error,
          text: 'Something failed',
        ),
      ]);
      expect(find.text('Something failed'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, Colors.red.shade100);
    });

    testWidgets('shows status styling for status entries', (tester) async {
      await pumpTimeline(tester, [
        const ConversationEntry(
          role: ConversationEntryRole.status,
          text: 'Loading...',
        ),
      ]);
      expect(find.text('Loading...'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, Colors.grey.shade200);
    });

    testWidgets('renders multiple entries with separators', (tester) async {
      await pumpTimeline(tester, [
        const ConversationEntry(role: ConversationEntryRole.user, text: 'Q1'),
        const ConversationEntry(
          role: ConversationEntryRole.assistant,
          text: 'A1',
        ),
        const ConversationEntry(role: ConversationEntryRole.user, text: 'Q2'),
      ]);
      expect(find.text('Q1'), findsOneWidget);
      expect(find.text('A1'), findsOneWidget);
      expect(find.text('Q2'), findsOneWidget);
      // 3 entries = 2 separators
      expect(find.byType(SizedBox), findsNWidgets(2));
    });

    testWidgets('shows "..." for empty non-generating assistant text', (
      tester,
    ) async {
      await pumpTimeline(tester, [
        const ConversationEntry(
          role: ConversationEntryRole.assistant,
          text: '',
          isComplete: true,
        ),
      ]);
      expect(find.text('...'), findsOneWidget);
    });

    testWidgets('applies maxWidth constraint of 520', (tester) async {
      await pumpTimeline(tester, [
        const ConversationEntry(
          role: ConversationEntryRole.user,
          text: 'Test',
        ),
      ]);
      // Find the ConstrainedBox that has maxWidth of 520
      final constrainedBoxes = tester.widgetList<ConstrainedBox>(
        find.byType(ConstrainedBox),
      );
      final target = constrainedBoxes.firstWhere(
        (cb) => cb.constraints.maxWidth == 520,
      );
      expect(target.constraints.maxWidth, 520);
    });
  });

  group('ConversationTimeline ContentBlock rendering', () {
    testWidgets('renders TextBlock content', (tester) async {
      await pumpTimeline(tester, [
        const ConversationEntry(
          role: ConversationEntryRole.assistant,
          text: '',
          contentBlocks: [TextBlock('Hello World')],
        ),
      ]);
      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('renders ErrorBlock with code prefix', (tester) async {
      await pumpTimeline(tester, [
        const ConversationEntry(
          role: ConversationEntryRole.assistant,
          text: '',
          contentBlocks: [ErrorBlock('failed', code: 'E001')],
        ),
      ]);
      expect(find.text('[E001] failed'), findsOneWidget);
    });

    testWidgets('renders ErrorBlock without code', (tester) async {
      await pumpTimeline(tester, [
        const ConversationEntry(
          role: ConversationEntryRole.assistant,
          text: '',
          contentBlocks: [ErrorBlock('something broke')],
        ),
      ]);
      expect(find.text('something broke'), findsOneWidget);
    });

    testWidgets('renders StatusBlock with italic style', (tester) async {
      await pumpTimeline(tester, [
        const ConversationEntry(
          role: ConversationEntryRole.assistant,
          text: '',
          contentBlocks: [StatusBlock('Processing...')],
        ),
      ]);
      final textWidget = tester.widget<Text>(find.text('Processing...'));
      expect(textWidget.style!.fontStyle, FontStyle.italic);
    });

    testWidgets('renders EmbeddingBlock with dimension and preview', (
      tester,
    ) async {
      await pumpTimeline(tester, [
        const ConversationEntry(
          role: ConversationEntryRole.assistant,
          text: '',
          contentBlocks: [
            EmbeddingBlock(dimension: 384, preview: [0.1, 0.2, 0.3]),
          ],
        ),
      ]);
      expect(find.text('Embedding 维度: 384'), findsOneWidget);
      expect(
        find.text('前5值: 0.1000, 0.2000, 0.3000'),
        findsOneWidget,
      );
    });

    testWidgets('renders OCRBlockDisplay with confidence and text', (
      tester,
    ) async {
      await pumpTimeline(tester, [
        const ConversationEntry(
          role: ConversationEntryRole.assistant,
          text: '',
          contentBlocks: [
            OCRBlockDisplay(text: '识别结果', confidence: 0.95),
          ],
        ),
      ]);
      expect(find.text('文字识别置信度: 95.0%'), findsOneWidget);
      expect(find.text('识别结果'), findsOneWidget);
    });

    testWidgets('renders MetricBlock with label and value', (tester) async {
      await pumpTimeline(tester, [
        const ConversationEntry(
          role: ConversationEntryRole.assistant,
          text: '',
          contentBlocks: [MetricBlock('置信度', '0.88')],
        ),
      ]);
      expect(find.text('置信度: 0.88'), findsOneWidget);
    });

    testWidgets('renders multiple ContentBlocks in order', (tester) async {
      await pumpTimeline(tester, [
        const ConversationEntry(
          role: ConversationEntryRole.assistant,
          text: '',
          contentBlocks: [
            TextBlock('STT 完成'),
            MetricBlock('置信度', '0.91'),
            MetricBlock('语言', 'zh'),
          ],
        ),
      ]);
      expect(find.text('STT 完成'), findsOneWidget);
      expect(find.text('置信度: 0.91'), findsOneWidget);
      expect(find.text('语言: zh'), findsOneWidget);
    });
  });
}
