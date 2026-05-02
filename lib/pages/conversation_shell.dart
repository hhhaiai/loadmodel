import 'package:flutter/material.dart';

import '../app/navigation_controller.dart';
import '../core/conversation_controller.dart';
import '../widgets/conversation_timeline.dart';

class ConversationShell extends StatefulWidget {
  const ConversationShell({super.key});

  @override
  State<ConversationShell> createState() => _ConversationShellState();
}

class _ConversationShellState extends State<ConversationShell> {
  final _controller = ConversationController();
  final _inputController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _handleSend() {
    final input = _inputController.text;
    if (input.trim().isEmpty) {
      _controller.send(input);
      return;
    }

    _inputController.clear();
    _controller.send(input);
  }

  void _switchToStatusPage() {
    appNavigationController.navigateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _switchToStatusPage,
          tooltip: '返回',
        ),
        title: const Text('对话'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return IconButton(
                key: const Key('conversation_clear_button'),
                tooltip: '清空对话',
                onPressed: _controller.entries.isEmpty ? null : _controller.reset,
                icon: const Icon(Icons.delete_outline),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return ConversationTimeline(entries: _controller.entries);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('conversation_input_field'),
                    controller: _inputController,
                    decoration: const InputDecoration(
                      labelText: '输入消息',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return SizedBox(
                      width: 120,
                      height: 50,
                      child: ElevatedButton.icon(
                        key: const Key('conversation_send_button'),
                        onPressed: _controller.isRunning
                            ? null
                            : _handleSend,
                        icon: Icon(
                          _controller.isRunning
                              ? Icons.hourglass_top
                              : Icons.send,
                          size: 20,
                        ),
                        label: const Text('发送'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
