import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../app/navigation_controller.dart';
import '../model_loader.dart';
import '../models/conversation_entry.dart';
import '../models/content_block.dart';
import '../utils/logger.dart';
import '../utils/status_messages.dart';
import '../widgets/conversation_timeline.dart';

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
  Uint8List? _selectedImageBytes;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Load default test image for OCR if initially selected
    if (_selectedType == 'ocr') {
      _loadDefaultOcrImage();
    }
  }

  Future<void> _loadDefaultOcrImage() async {
    try {
      final data = await rootBundle.load('assets/models/ocr/test_english.png');
      if (!mounted) return;
      setState(() {
        _selectedImageBytes = data.buffer.asUint8List();
      });
    } catch (e) {
      logger.warning('Failed to load default OCR test image', e);
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 95,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (bytes.lengthInBytes > 10 * 1024 * 1024) {
        _appendEntry(
          const ConversationEntry(
            role: ConversationEntryRole.error,
            text: '图片过大（超过 10MB），请选择较小的图片',
          ),
        );
        return;
      }
      setState(() => _selectedImageBytes = bytes);
    } catch (e) {
      logger.warning('Failed to pick image: $source', e);
      if (!mounted) return;
      final message = e is PlatformException
          ? '无法获取图片，请检查权限设置'
          : '无法获取图片';
      _appendEntry(
        ConversationEntry(
          role: ConversationEntryRole.error,
          text: message,
        ),
      );
    }
  }

  Widget _buildTestImageChip(String label, String assetName) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: _isRunning
          ? null
          : () async {
              try {
                final data = await rootBundle.load('assets/models/ocr/$assetName');
                if (!mounted) return;
                setState(() {
                  _selectedImageBytes = data.buffer.asUint8List();
                });
              } catch (e) {
                logger.warning('Failed to load test image: $assetName', e);
              }
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => appNavigationController.navigateTo(0),
          tooltip: '返回',
        ),
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
                DropdownMenuItem(value: 'ocr', child: Text('📷 OCR')),
                DropdownMenuItem(value: 'caption', child: Text('🖼️ Caption')),
              ],
              onChanged: (v) {
                setState(() {
                  _selectedType = v!;
                  if (v != 'ocr' && v != 'caption') _selectedImageBytes = null;
                });
                if ((v == 'ocr' || v == 'caption') && _selectedImageBytes == null) {
                  _loadDefaultOcrImage();
                }
              },
            ),
            const SizedBox(height: 16),
            // OCR / Caption 图片选择区域
            if (_selectedType == 'ocr' || _selectedType == 'caption') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('ocr_camera_button'),
                      onPressed: _isRunning
                          ? null
                          : () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('拍照识别'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('ocr_gallery_button'),
                      onPressed: _isRunning
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('选择图片'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 图片预览
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _selectedImageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _selectedImageBytes!,
                          fit: BoxFit.contain,
                        ),
                      )
                    : const Center(
                        child: Text(
                          '请拍照或选择图片',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              // 测试图片快速选择
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildTestImageChip('English', 'test_english.png'),
                  _buildTestImageChip('Model', 'test_english_v2.png'),
                  _buildTestImageChip('ASCII', 'test_ascii.png'),
                  _buildTestImageChip('Numbers', 'test_numbers.png'),
                  _buildTestImageChip('Word', 'test_word.png'),
                  _buildTestImageChip('Mixed', 'test_mixed.png'),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedType != 'ocr' && _selectedType != 'caption')
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
                if (_selectedType != 'ocr') const SizedBox(width: 12),
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
                    label: Text(_isRunning ? '...' : (_selectedType == 'ocr' ? '识别' : '描述')),
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
              text: '',
              contentBlocks: [
                const TextBlock('✅ Embedding 完成'),
                EmbeddingBlock(
                  dimension: result.dimension,
                  preview: result.embedding.take(5).toList(),
                ),
              ],
            ),
          );
          break;

        case 'stt':
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
          if (!ml.stt.isLoaded) {
            _appendEntry(
              ConversationEntry(
                role: ConversationEntryRole.error,
                text: buildTestModelNotLoadedStatus(taskLabel: 'STT'),
              ),
            );
            return;
          }
          final sttAssetData =
              await rootBundle.load('assets/models/whisper/test_audio.wav');
          final sttAudioBytes =
              sttAssetData.buffer.asUint8List(sttAssetData.offsetInBytes, sttAssetData.lengthInBytes);
          final sttResult = await ml.stt.recognizeBytes(sttAudioBytes);
          _appendEntry(
            ConversationEntry(
              role: ConversationEntryRole.assistant,
              text: '',
              contentBlocks: [
                const TextBlock('🎤 STT 完成'),
                TextBlock('文本: ${sttResult.text}'),
                MetricBlock('置信度', sttResult.confidence.toStringAsFixed(2)),
                MetricBlock('语言', sttResult.language ?? 'unknown'),
              ],
            ),
          );
          break;

        case 'ocr':
          _appendEntry(
            const ConversationEntry(
              role: ConversationEntryRole.user,
              text: '📷 OCR 识别',
            ),
          );
          if (!ml.ocr.isLoaded) {
            _appendEntry(
              ConversationEntry(
                role: ConversationEntryRole.error,
                text: buildTestModelNotLoadedStatus(taskLabel: 'OCR'),
              ),
            );
            return;
          }
          if (_selectedImageBytes == null) {
            _appendEntry(
              ConversationEntry(
                role: ConversationEntryRole.error,
                text: buildTestInferenceFailedStatus(
                  taskLabel: 'OCR',
                  reason: '请先拍照或选择图片',
                ),
              ),
            );
            return;
          }
          final ocrResult = await ml.ocr.recognizeBytes(_selectedImageBytes!);
          _appendEntry(
            ConversationEntry(
              role: ConversationEntryRole.assistant,
              text: '',
              contentBlocks: [
                const TextBlock('📷 OCR 识别完成'),
                OCRBlockDisplay(
                  text: ocrResult.text,
                  confidence: ocrResult.averageConfidence,
                  imageBytes: _selectedImageBytes,
                ),
              ],
            ),
          );
          break;

        case 'caption':
          _appendEntry(
            const ConversationEntry(
              role: ConversationEntryRole.user,
              text: '🖼️ 图片描述',
            ),
          );
          if (!ml.imageCaption.isLoaded) {
            _appendEntry(
              ConversationEntry(
                role: ConversationEntryRole.error,
                text: buildTestModelNotLoadedStatus(taskLabel: 'Image Caption'),
              ),
            );
            return;
          }
          if (_selectedImageBytes == null) {
            _appendEntry(
              ConversationEntry(
                role: ConversationEntryRole.error,
                text: buildTestInferenceFailedStatus(
                  taskLabel: 'Image Caption',
                  reason: '请先拍照或选择图片',
                ),
              ),
            );
            return;
          }
          final captionResult = await ml.imageCaption.captionBytes(_selectedImageBytes!);
          _appendEntry(
            ConversationEntry(
              role: ConversationEntryRole.assistant,
              text: '',
              contentBlocks: [
                const TextBlock('🖼️ 图片描述完成'),
                ImageCaptionBlock(
                  caption: captionResult.caption,
                  confidence: captionResult.confidence,
                  imageBytes: _selectedImageBytes,
                  candidates: captionResult.candidates.isEmpty
                      ? null
                      : captionResult.candidates
                          .map((c) => CaptionDisplayCandidate(
                                text: c.text,
                                confidence: c.confidence,
                              ))
                          .toList(),
                ),
              ],
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
