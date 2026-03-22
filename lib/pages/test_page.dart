import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model_loader.dart';
import '../models/conversation_entry.dart';
import '../models/model_loader_exception.dart';
import '../utils/logger.dart';
import '../widgets/conversation_timeline.dart';

String buildTestModelNotLoadedStatus({required String taskLabel}) {
  final code = ModelLoaderErrorCode.MODEL_LOAD_FAILED.code;
  return '❌ [$code] $taskLabel 模型未加载\n\n先到"加载"页面加载 $taskLabel 模型';
}

String buildTestInferenceFailedStatus({
  required String taskLabel,
  String? reason,
}) {
  final code = ModelLoaderErrorCode.INFERENCE_FAILED.code;
  final reasonText = reason != null && reason.isNotEmpty ? '\n原因: $reason' : '';
  return '❌ [$code] $taskLabel 推理失败$reasonText\n请查看日志获取详细信息';
}

String buildTestRuntimeUnavailableStatus({
  required String taskLabel,
  String? reason,
}) {
  final code = ModelLoaderErrorCode.RUNTIME_NOT_AVAILABLE.code;
  final reasonText = reason != null && reason.isNotEmpty ? '\n原因: $reason' : '';
  return '⚠️ [$code] $taskLabel 运行时当前不可用$reasonText\n请切换平台或补齐该能力的原生实现';
}

/// 测试页面
class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final _inputController = TextEditingController(text: '你好世界');
  final List<ConversationEntry> _entries = [];
  bool _isRunning = false;
  String _selectedType = 'embedding';

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('测试'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              key: const Key('test_type_dropdown'),
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: '测试类型',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'embedding',
                  child: Text('📊 Embedding'),
                ),
                DropdownMenuItem(value: 'stt', child: Text('🎤 STT')),
                DropdownMenuItem(value: 'tts', child: Text('🔊 TTS')),
                DropdownMenuItem(value: 'ocr', child: Text('📷 OCR')),
              ],
              onChanged: (v) => setState(() => _selectedType = v!),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('test_input_field'),
                    controller: _inputController,
                    decoration: const InputDecoration(
                      labelText: '输入',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    key: const Key('test_send_button'),
                    onPressed: _isRunning ? null : _runTest,
                    icon: _isRunning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isRunning ? '...' : '发送'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ConversationTimeline(
                  entries: _entries,
                  emptyStateText: '结果将显示在这里',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runTest() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      _appendEntry(
        const ConversationEntry(
          role: ConversationEntryRole.error,
          text: '请输入内容',
        ),
      );
      return;
    }

    _appendEntry(
      ConversationEntry(role: ConversationEntryRole.user, text: input),
    );

    setState(() {
      _isRunning = true;
      _entries.add(
        ConversationEntry(
          role: ConversationEntryRole.status,
          text: '$_selectedType 处理中...',
          isComplete: false,
        ),
      );
    });

    try {
      final ml = ModelLoader.instance;

      switch (_selectedType) {
        case 'embedding':
          if (!ml.embedding.isLoaded) {
            _appendEntry(
              ConversationEntry(
                role: ConversationEntryRole.error,
                text: buildTestModelNotLoadedStatus(taskLabel: 'Embedding'),
              ),
            );
            return;
          }
          final result = await ml.embedding.getEmbedding(input);
          _appendEntry(
            ConversationEntry(
              role: ConversationEntryRole.assistant,
              text:
                  '✅ Embedding 结果:\n维度: ${result.dimension}\n前5个值: ${result.embedding.take(5).toList()}',
            ),
          );
          break;

        case 'stt':
          if (!ml.stt.isLoaded) {
            _appendEntry(
              ConversationEntry(
                role: ConversationEntryRole.error,
                text: buildTestModelNotLoadedStatus(taskLabel: 'STT'),
              ),
            );
            return;
          }
          final fakePcm16 = Uint8List.fromList(List<int>.filled(3200, 0));
          final result = await ml.stt.recognizeBytes(fakePcm16);
          _appendEntry(
            ConversationEntry(
              role: ConversationEntryRole.assistant,
              text:
                  '🎤 STT 结果:\n文本: ${result.text}\n置信度: ${result.confidence.toStringAsFixed(2)}\n语言: ${result.language ?? 'unknown'}',
            ),
          );
          break;

        case 'tts':
          _appendEntry(
            ConversationEntry(
              role: ConversationEntryRole.error,
              text: buildTestRuntimeUnavailableStatus(taskLabel: 'TTS'),
            ),
          );
          break;

        case 'ocr':
          if (!ml.ocr.isLoaded) {
            _appendEntry(
              ConversationEntry(
                role: ConversationEntryRole.error,
                text: buildTestModelNotLoadedStatus(taskLabel: 'OCR'),
              ),
            );
            return;
          }
          final onePixelPng = Uint8List.fromList(const [
            0x89,
            0x50,
            0x4E,
            0x47,
            0x0D,
            0x0A,
            0x1A,
            0x0A,
            0x00,
            0x00,
            0x00,
            0x0D,
            0x49,
            0x48,
            0x44,
            0x52,
            0x00,
            0x00,
            0x00,
            0x01,
            0x00,
            0x00,
            0x00,
            0x01,
            0x08,
            0x06,
            0x00,
            0x00,
            0x00,
            0x1F,
            0x15,
            0xC4,
            0x89,
            0x00,
            0x00,
            0x00,
            0x0D,
            0x49,
            0x44,
            0x41,
            0x54,
            0x78,
            0x9C,
            0x63,
            0xF8,
            0xCF,
            0xC0,
            0xF0,
            0x1F,
            0x00,
            0x05,
            0x00,
            0x01,
            0xFF,
            0x89,
            0x99,
            0x3D,
            0x1D,
            0x00,
            0x00,
            0x00,
            0x00,
            0x49,
            0x45,
            0x4E,
            0x44,
            0xAE,
            0x42,
            0x60,
            0x82,
          ]);
          final result = await ml.ocr.recognizeBytes(onePixelPng);
          _appendEntry(
            ConversationEntry(
              role: ConversationEntryRole.assistant,
              text:
                  '📷 OCR 结果:\n文本: ${result.text}\n置信度: ${result.averageConfidence.toStringAsFixed(2)}',
            ),
          );
          break;
      }
    } catch (e, st) {
      logger.warning('Test flow failed', e, st);
      final message =
          e is PlatformException &&
              (e.code == 'RUNTIME_NOT_AVAILABLE' || e.code == 'NOT_IMPLEMENTED')
          ? buildTestRuntimeUnavailableStatus(
              taskLabel: _selectedType.toUpperCase(),
              reason: e.message ?? e.toString(),
            )
          : buildTestInferenceFailedStatus(
              taskLabel: _selectedType.toUpperCase(),
              reason: e.toString(),
            );
      _appendEntry(
        ConversationEntry(role: ConversationEntryRole.error, text: message),
      );
    } finally {
      if (mounted) {
        setState(() {
          _removePendingStatus();
          _isRunning = false;
        });
      }
    }
  }

  void _appendEntry(ConversationEntry entry) {
    if (!mounted) {
      return;
    }
    setState(() {
      _entries.add(entry);
    });
  }

  void _removePendingStatus() {
    _entries.removeWhere(
      (entry) =>
          entry.role == ConversationEntryRole.status && !entry.isComplete,
    );
  }
}
