import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/asset_helper.dart';
import '../model_loader.dart';
import '../models/llm_model_catalog.dart';
import '../models/model_type.dart';
import '../runtime/embedding_runtime.dart';
import '../runtime/ocr_runtime.dart';
import '../runtime/stt_runtime.dart';
import '../models/model_loader_exception.dart';
import '../utils/logger.dart';

String buildMissingAssetStatus({
  required String modelDir,
  required String taskLabel,
  required List<String> requiredFiles,
}) {
  final code = ModelLoaderErrorCode.MODEL_NOT_FOUND.code;
  final files = requiredFiles.map((f) => '- $f').join('\n');
  return '❌ [$code] $taskLabel 模型文件缺失\n'
      '目录: assets/models/$modelDir/\n'
      '需要文件:\n$files';
}

String buildRuntimeLoadFailedStatus({
  required String taskLabel,
  String? reason,
}) {
  final code = ModelLoaderErrorCode.MODEL_LOAD_FAILED.code;
  final suffix = (reason == null || reason.isEmpty) ? '' : '\n原因: $reason';
  return '❌ [$code] $taskLabel 模型加载失败$suffix';
}

String buildRuntimeUnavailableStatus({
  required String taskLabel,
  String? reason,
}) {
  final code = ModelLoaderErrorCode.RUNTIME_NOT_AVAILABLE.code;
  final suffix = (reason == null || reason.isEmpty) ? '' : '\n原因: $reason';
  return '⚠️ [$code] $taskLabel 运行时当前不可用$suffix\n请切换平台或补齐该能力的原生实现';
}

String buildMissingLlmAssetStatus({required String assetPath}) {
  final code = ModelLoaderErrorCode.MODEL_NOT_FOUND.code;
  return '❌ [$code] LLM 模型文件缺失\n'
      '文件: $assetPath\n'
      '请确保模型文件存在于 assets 目录';
}

/// 模型加载页面
class ModelLoadPage extends StatefulWidget {
  const ModelLoadPage({super.key, this.loadModelAssets, this.resolveAssetPath});

  final Future<Map<String, String>> Function({
    required String modelDir,
    String? modelFile,
    String? tokenizerFile,
  })?
  loadModelAssets;

  final Future<String?> Function(String assetPath)? resolveAssetPath;

  @override
  State<ModelLoadPage> createState() => _ModelLoadPageState();
}

class _ModelLoadPageState extends State<ModelLoadPage> {
  String _selectedType = 'embedding';
  String _selectedLLMModel = LLMModelCatalog.defaultModelId;
  bool _isLoading = false;
  String _status = '';

  Future<bool> _isPlaceholderModelFile(String modelPath) async {
    try {
      final file = File(modelPath);
      if (!await file.exists()) {
        return false;
      }
      final bytes = await file
          .openRead(0, 128)
          .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
      final prefix = utf8.decode(bytes, allowMalformed: true).toLowerCase();
      return prefix.contains('placeholder') && prefix.contains('onnx model');
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, String>> _loadAssets({
    required String modelDir,
    String? modelFile,
    String? tokenizerFile,
  }) {
    final loader = widget.loadModelAssets;
    if (loader != null) {
      return loader(
        modelDir: modelDir,
        modelFile: modelFile,
        tokenizerFile: tokenizerFile,
      );
    }

    return AssetHelper().loadModelAssets(
      modelDir: modelDir,
      modelFile: modelFile,
      tokenizerFile: tokenizerFile,
    );
  }

  Future<String?> _resolveAssetPath(String assetPath) {
    final resolver = widget.resolveAssetPath;
    if (resolver != null) {
      return resolver(assetPath);
    }
    return AssetHelper().getOptimizedAssetPath(assetPath);
  }

  @override
  void initState() {
    super.initState();
    final saved = ModelLoader.instance.configManager.uiSettings;
    final savedModel = saved['selectedLLMModel']?.toString();
    if (savedModel != null && LLMModelCatalog.bundledIds.contains(savedModel)) {
      _selectedLLMModel = savedModel;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('加载模型'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            key: const Key('load_model_type_dropdown'),
            initialValue: _selectedType,
            decoration: const InputDecoration(
              labelText: '模型类型',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'embedding',
                child: Text('📊 Embedding (文本向量)'),
              ),
              DropdownMenuItem(value: 'stt', child: Text('🎤 STT (语音识别)')),
              DropdownMenuItem(value: 'ocr', child: Text('📷 OCR (文字识别)')),
              DropdownMenuItem(value: 'llm', child: Text('💬 LLM (对话模型)')),
            ],
            onChanged: (v) => setState(() {
              _selectedType = v!;
              _status = '';
            }),
          ),
          const SizedBox(height: 16),
          if (_selectedType == 'llm')
            Column(
              children: [
                DropdownButtonFormField<String>(
                  key: const Key('load_llm_model_dropdown'),
                  initialValue: _selectedLLMModel,
                  decoration: const InputDecoration(
                    labelText: 'LLM 模型',
                    border: OutlineInputBorder(),
                  ),
                  items: LLMModelCatalog.bundledIds.map((modelId) {
                    final option = LLMModelCatalog.getById(modelId)!;
                    return DropdownMenuItem<String>(
                      value: option.id,
                      child: Text(option.loadDropdownLabel),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() {
                    _selectedLLMModel = v!;
                    _status = '';
                  }),
                ),
                const SizedBox(height: 16),
              ],
            ),
          _buildRuntimeInfo(),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            key: const Key('load_model_button'),
            onPressed: _isLoading ? null : _loadModel,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload),
            label: Text(_isLoading ? '加载中...' : '加载模型'),
          ),
          const SizedBox(height: 16),
          if (_status.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _status.contains('成功')
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_status),
            ),
        ],
      ),
    );
  }

  Widget _buildRuntimeInfo() {
    final ml = ModelLoader.instance;
    final isMobile = ml.platform.isMobile;
    final modelType = _selectedType == 'llm'
        ? ModelType.llm
        : _selectedType == 'embedding'
        ? ModelType.embedding
        : _selectedType == 'stt'
        ? ModelType.stt
        : ModelType.ocr;

    final runtime = ml.getRecommendedRuntime(modelType);
    final configuredRuntime = ml.describeCurrentRuntime(modelType);

    return Card(
      color: isMobile ? Colors.orange.shade50 : Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isMobile ? Icons.phone_android : Icons.desktop_windows,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  isMobile ? '移动端运行时' : '桌面端运行时',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...[
              Text(runtime.description),
              Text(
                '当前实现: $configuredRuntime',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                '推荐运行时: ${runtime.runtime}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadModel() async {
    setState(() {
      _isLoading = true;
      _status = '开始加载模型...';
    });

    try {
      final ml = ModelLoader.instance;
      ModelType? selectedModelType;
      String? selectedModelId;
      if (_selectedType == 'embedding') {
        final saved = ModelLoader.instance.configManager.uiSettings;
        final selectedEmbeddingModel = saved['selectedEmbeddingModel']
            ?.toString();
        selectedModelType = ModelType.embedding;
        selectedModelId = selectedEmbeddingModel == 'bge-small-zh'
            ? 'bge-small-zh'
            : 'bge-small';
      } else if (_selectedType == 'llm') {
        selectedModelType = ModelType.llm;
        selectedModelId = _selectedLLMModel;
      }

      if (selectedModelType != null) {
        final report = ml.selectRuntimeForLoadType(
          type: selectedModelType,
          modelId: selectedModelId,
        );
        if (report != null) {
          logger.info('Load flow selection report: ${report.toJson()}');
          _status =
              '运行时选择: ${report.finalDecision.backend.name}/${report.finalDecision.provider.name}'
              '\nthreads=${report.finalDecision.threads}, '
              'ctx=${report.finalDecision.contextLength}, '
              'gpuLayers=${report.finalDecision.gpuLayers}';
        }
      }

      switch (_selectedType) {
        case 'embedding':
          try {
            final saved = ModelLoader.instance.configManager.uiSettings;
            final selectedEmbeddingModel = saved['selectedEmbeddingModel']
                ?.toString();
            final modelDir = selectedEmbeddingModel == 'bge-small-zh'
                ? 'bge-small-zh'
                : 'bge-small';

            final assets = await _loadAssets(
              modelDir: modelDir,
              modelFile: 'model.onnx',
              tokenizerFile: 'tokenizer.json',
            );

            if (assets.isNotEmpty && assets.containsKey('modelPath')) {
              await ml.embedding.loadModel(
                EmbeddingConfig(
                  modelPath: assets['modelPath']!,
                  tokenizerPath: assets['tokenizerPath'],
                  maxLength: 512,
                ),
              );
              _status = '✅ Embedding 模型加载成功 ($modelDir)';
            } else {
              _status = buildMissingAssetStatus(
                modelDir: modelDir,
                taskLabel: 'Embedding',
                requiredFiles: const ['model.onnx', 'tokenizer.json'],
              );
            }
          } catch (e, st) {
            logger.warning('Embedding asset load failed', e, st);
            _status = _buildLoadErrorStatus(taskLabel: 'Embedding', error: e);
          }
          break;

        case 'stt':
          try {
            final assets = await _loadAssets(
              modelDir: 'whisper',
              modelFile: 'model.onnx',
            );
            if (assets.containsKey('modelPath')) {
              final modelPath = assets['modelPath']!;
              if (await _isPlaceholderModelFile(modelPath)) {
                _status = buildMissingAssetStatus(
                  modelDir: 'whisper',
                  taskLabel: 'STT',
                  requiredFiles: const ['model.onnx', 'model_config.json'],
                );
                break;
              }
              // Also copy encoder, decoder, and vocab files for Whisper STT
              final helper = AssetHelper();
              await helper.loadAssetToCache(
                'assets/models/whisper/onnx/encoder_model.onnx',
              );
              await helper.loadAssetToCache(
                'assets/models/whisper/onnx/decoder_model_merged.onnx',
              );
              await helper.loadAssetToCache(
                'assets/models/whisper/vocab.json',
              );
              await ml.stt.loadModel(
                STTConfig(modelPath: modelPath, language: 'auto'),
              );
              _status = '✅ STT 模型加载成功 (whisper)';
            } else {
              _status = buildMissingAssetStatus(
                modelDir: 'whisper',
                taskLabel: 'STT',
                requiredFiles: const ['model.onnx', 'model_config.json'],
              );
            }
          } catch (e, st) {
            logger.warning('STT load failed', e, st);
            _status = _buildLoadErrorStatus(taskLabel: 'STT', error: e);
          }
          break;

        case 'ocr':
          try {
            final assets = await _loadAssets(
              modelDir: 'ocr',
              modelFile: 'model.onnx',
            );
            if (assets.containsKey('modelPath')) {
              final modelPath = assets['modelPath']!;
              if (await _isPlaceholderModelFile(modelPath)) {
                _status = buildMissingAssetStatus(
                  modelDir: 'ocr',
                  taskLabel: 'OCR',
                  requiredFiles: const ['model.onnx', 'model_config.json'],
                );
                break;
              }
              await ml.ocr.loadModel(
                OCRConfig(modelPath: modelPath, language: 'eng+chi_sim'),
              );
              _status = '✅ OCR 模型加载成功 (ocr)';
            } else {
              _status = buildMissingAssetStatus(
                modelDir: 'ocr',
                taskLabel: 'OCR',
                requiredFiles: const ['model.onnx', 'model_config.json'],
              );
            }
          } catch (e, st) {
            logger.warning('OCR load failed', e, st);
            _status = _buildLoadErrorStatus(taskLabel: 'OCR', error: e);
          }
          break;

        case 'llm':
          try {
            final selectedModel = LLMModelCatalog.getById(_selectedLLMModel);
            if (selectedModel == null || !selectedModel.isBundled) {
              _status = buildRuntimeLoadFailedStatus(
                taskLabel: 'LLM',
                reason: '未找到可加载的 LLM 配置: $_selectedLLMModel',
              );
              break;
            }

            final modelPath = await _resolveAssetPath(selectedModel.assetPath!);

            if (modelPath != null) {
              final resolved = ml.resolveLLMLoadConfig(
                modelPath: modelPath,
                modelId: selectedModel.id,
              );
              final llmConfig = resolved.config;
              final report = resolved.selectionReport;

              await ml.llm.loadModel(llmConfig);
              _status =
                  '✅ LLM 模型加载成功!\n\n'
                  '模型: ${selectedModel.successName}\n'
                  '后端: ${report?.finalDecision.backend.name ?? 'unknown'}/'
                  '${report?.finalDecision.provider.name ?? 'cpu'}\n'
                  '上下文: ${llmConfig.contextLength}, 线程: ${llmConfig.threads ?? '-'}, '
                  'GPU Layers: ${llmConfig.gpuLayers ?? 0}\n'
                  '你可以到"测试"页面进行对话测试';
            } else {
              _status = buildMissingLlmAssetStatus(
                assetPath: selectedModel.assetPath!,
              );
            }
          } catch (e, st) {
            logger.warning('LLM load failed', e, st);
            _status = _buildLoadErrorStatus(taskLabel: 'LLM', error: e);
          }
          break;
      }
    } catch (e, st) {
      logger.warning('Model load flow failed', e, st);
      _status = '❌ 加载失败，请稍后重试';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _buildLoadErrorStatus({
    required String taskLabel,
    required Object error,
  }) {
    if (error is PlatformException &&
        (error.code == 'RUNTIME_NOT_AVAILABLE' ||
            error.code == 'NOT_IMPLEMENTED')) {
      return buildRuntimeUnavailableStatus(
        taskLabel: taskLabel,
        reason: error.message ?? error.toString(),
      );
    }

    return buildRuntimeLoadFailedStatus(
      taskLabel: taskLabel,
      reason: error.toString(),
    );
  }
}
