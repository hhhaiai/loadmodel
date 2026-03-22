import 'package:flutter/foundation.dart';

import '../model_loader.dart';
import '../models/conversation_entry.dart';
import '../models/inference_event.dart';
import '../models/inference_event_mapper.dart';
import '../pages/test_page.dart';
import '../runtime/llm_runtime.dart';

class ConversationController extends ChangeNotifier {
  final List<ConversationEntry> _entries = [];
  bool _isRunning = false;
  bool _isDisposed = false;
  int _activeRequestToken = 0;

  List<ConversationEntry> get entries => List.unmodifiable(_entries);
  bool get isRunning => _isRunning;

  void reset() {
    _activeRequestToken++;
    _isRunning = false;
    _entries.clear();
    _notifySafely();
  }

  GenerationConfig currentGenerationConfig() {
    final saved = ModelLoader.instance.configManager.uiSettings;
    final temperature = ((saved['temperature'] as num?)?.toDouble() ?? 0.7)
        .clamp(0.0, 2.0);
    final maxTokens = ((saved['maxTokens'] as num?)?.toInt() ?? 2048).clamp(
      1,
      4096,
    );
    return GenerationConfig(
      temperature: temperature,
      maxTokens: maxTokens,
      topP: 0.9,
    );
  }

  Future<void> send(String input) async {
    final prompt = input.trim();
    if (prompt.isEmpty) {
      _entries.add(
        const ConversationEntry(
          role: ConversationEntryRole.error,
          text: '请输入内容',
        ),
      );
      _notifySafely();
      return;
    }

    final ml = ModelLoader.instance;
    if (!ml.llm.isLoaded) {
      _entries.add(
        ConversationEntry(
          role: ConversationEntryRole.error,
          text: buildTestModelNotLoadedStatus(taskLabel: 'LLM'),
        ),
      );
      _notifySafely();
      return;
    }

    final requestToken = ++_activeRequestToken;
    _isRunning = true;
    final userIndex = _entries.length;
    _entries.add(
      ConversationEntry(
        role: ConversationEntryRole.user,
        text: prompt,
        isComplete: false,
      ),
    );
    final assistantIndex = _entries.length;
    _entries.add(
      const ConversationEntry(
        role: ConversationEntryRole.assistant,
        text: '',
        isComplete: false,
      ),
    );
    _notifySafely();

    final messages = _buildChatHistory(currentPrompt: prompt);

    try {
      await for (final rawEvent in ml.llm.chatStreamEvents(
        messages,
        config: currentGenerationConfig(),
      )) {
        if (!_shouldProcess(requestToken)) {
          return;
        }

        final event = InferenceEventMapper.fromLLMStreamEvent(rawEvent);

        switch (event.kind) {
          case InferenceEventKind.delta:
            final current = _entries[assistantIndex];
            _entries[assistantIndex] = current.copyWith(
              text: '${current.text}${event.textDelta ?? ''}',
              isComplete: false,
            );
            break;
          case InferenceEventKind.error:
            _entries[assistantIndex] = ConversationEntry(
              role: ConversationEntryRole.error,
              text: buildTestInferenceFailedStatus(
                taskLabel: 'LLM',
                reason: event.error?.message,
              ),
            );
            _isRunning = false;
            _notifySafely();
            return;
          case InferenceEventKind.finish:
            _entries[userIndex] = _entries[userIndex].copyWith(
              isComplete: true,
            );
            final current = _entries[assistantIndex];
            _entries[assistantIndex] = current.copyWith(
              text: current.text,
              isComplete: true,
            );
            break;
          case InferenceEventKind.metrics:
          case InferenceEventKind.result:
            break;
        }
        _notifySafely();
      }
    } catch (e) {
      if (_shouldProcess(requestToken)) {
        _entries[assistantIndex] = ConversationEntry(
          role: ConversationEntryRole.error,
          text: buildTestInferenceFailedStatus(
            taskLabel: 'LLM',
            reason: e.toString(),
          ),
        );
        _notifySafely();
      }
    } finally {
      if (_shouldProcess(requestToken)) {
        _isRunning = false;
        _notifySafely();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _activeRequestToken++;
    super.dispose();
  }

  List<ChatMessage> _buildChatHistory({required String currentPrompt}) {
    final history = <ChatMessage>[];
    final systemPrompt = _systemPrompt();
    if (systemPrompt != null) {
      history.add(ChatMessage.system(systemPrompt));
    }

    for (final entry in _entries) {
      if (!entry.isComplete) {
        continue;
      }

      switch (entry.role) {
        case ConversationEntryRole.user:
          history.add(ChatMessage.user(entry.text));
          break;
        case ConversationEntryRole.assistant:
          final assistantText = _normalizeAssistantHistoryText(entry.text);
          if (assistantText.isNotEmpty) {
            history.add(ChatMessage.assistant(assistantText));
          }
          break;
        case ConversationEntryRole.status:
        case ConversationEntryRole.error:
          break;
      }
    }

    history.add(ChatMessage.user(currentPrompt));
    return List<ChatMessage>.unmodifiable(history);
  }

  String? _systemPrompt() {
    final raw =
        ModelLoader.instance.configManager.uiSettings['systemPrompt']
            ?.toString() ??
        '';
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : raw;
  }

  String _normalizeAssistantHistoryText(String text) {
    const marker = '\n\n[完成]';
    return text.endsWith(marker)
        ? text.substring(0, text.length - marker.length)
        : text;
  }

  bool _shouldProcess(int requestToken) =>
      !_isDisposed && requestToken == _activeRequestToken;

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }
}
