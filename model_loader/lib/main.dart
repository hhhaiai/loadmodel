import 'package:flutter/material.dart';
import 'model_loader.dart';
import 'utils/logger.dart';
import 'runtime/onnx_runtime_flutter.dart';
import 'runtime/llm_runtime.dart';
import 'models/model_type.dart';
import 'models/model_registry.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 ModelLoader SDK
  await ModelLoader.initialize(
    config: const ModelLoaderConfig(
      enableRemoteModels: false,
      logLevel: LogLevel.info,
      autoSelectRuntime: true,
    ),
  );

  // 设置平台特定的运行时
  final ml = ModelLoader.instance;

  // iOS/Android 使用 ONNX
  if (ml.platform.isMobile) {
    try {
      ml.setOCRRuntime(ONNXRuntimes.ocr);
      ml.setSTTRuntime(ONNXRuntimes.stt);
      ml.setEmbeddingRuntime(ONNXRuntimes.embedding);
      logger.info('Mobile runtimes configured');
    } catch (e) {
      logger.warning('Failed to configure ONNX runtimes: $e');
    }
  }
  // 桌面端使用 llama.cpp + ONNX
  else if (ml.platform.isDesktop) {
    // TODO: 配置 llama.cpp
    logger.info('Desktop - llama.cpp will be loaded when available');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ModelLoader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    StatusPage(),
    ModelLoadPage(),
    TestPage(),
    ModelsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.info_outline), label: '状态'),
          NavigationDestination(icon: Icon(Icons.folder_open), label: '加载'),
          NavigationDestination(icon: Icon(Icons.play_circle_outline), label: '测试'),
          NavigationDestination(icon: Icon(Icons.apps), label: '模型'),
        ],
      ),
    );
  }
}

/// 状态页面
class StatusPage extends StatelessWidget {
  const StatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ml = ModelLoader.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('状态'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            context,
            '📱 平台信息',
            [
              _buildRow('平台', ml.platform.name.toUpperCase()),
              _buildRow('移动端', ml.platform.isMobile ? '✅' : '❌'),
              _buildRow('桌面端', ml.platform.isDesktop ? '✅' : '❌'),
              _buildRow('量化支持', ml.platform.isDesktop ? '✅' : '❌ (仅桌面)'),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            '⚙️ 运行时状态',
            [
              _buildRow('LLM', ml.llm.isLoaded ? '✅ 已加载' : '❌ 未加载'),
              _buildRow('OCR', ml.ocr.isLoaded ? '✅ 已加载' : '❌ 未加载'),
              _buildRow('TTS', ml.tts.isLoaded ? '✅ 已加载' : '❌ 未加载'),
              _buildRow('STT', ml.stt.isLoaded ? '✅ 已加载' : '❌ 未加载'),
              _buildRow('Embedding', ml.embedding.isLoaded ? '✅ 已加载' : '❌ 未加载'),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            '📁 目录',
            [
              _buildRow('缓存', ml.config.cacheDir),
              _buildRow('自定义', ml.config.customDir),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

/// 模型加载页面
class ModelLoadPage extends StatefulWidget {
  const ModelLoadPage({super.key});

  @override
  State<ModelLoadPage> createState() => _ModelLoadPageState();
}

class _ModelLoadPageState extends State<ModelLoadPage> {
  String _selectedType = 'embedding';
  bool _isLoading = false;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('加载模型'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: '模型类型',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'embedding', child: Text('📊 Embedding (文本向量)')),
                DropdownMenuItem(value: 'stt', child: Text('🎤 STT (语音识别)')),
                DropdownMenuItem(value: 'tts', child: Text('🔊 TTS (语音合成)')),
                DropdownMenuItem(value: 'ocr', child: Text('📷 OCR (文字识别)')),
                DropdownMenuItem(value: 'llm', child: Text('💬 LLM (对话模型)')),
              ],
              onChanged: (v) => setState(() {
                _selectedType = v!;
                _status = '';
              }),
            ),
            const SizedBox(height: 16),
            // 显示推荐运行时
            _buildRuntimeInfo(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _loadModel,
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload),
              label: Text(_isLoading ? '加载中...' : '加载模型'),
            ),
            const SizedBox(height: 16),
            if (_status.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _status.contains('成功') ? Colors.green.shade100 : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_status),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuntimeInfo() {
    final ml = ModelLoader.instance;
    final runtime = ml.getRecommendedRuntime(
      _selectedType == 'llm'
          ? ModelType.llm
          : _selectedType == 'embedding'
              ? ModelType.embedding
              : _selectedType == 'stt'
                  ? ModelType.stt
                  : _selectedType == 'tts'
                      ? ModelType.tts
                      : ModelType.ocr,
    );

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💡 推荐运行时', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(runtime.description),
            Text('运行时: ${runtime.runtime}', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _loadModel() async {
    setState(() {
      _isLoading = true;
      _status = '请在"模型"页面查看支持的模型';
    });

    await Future.delayed(const Duration(seconds: 1));

    setState(() => _isLoading = false);
  }
}

/// 测试页面
class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final _inputController = TextEditingController(text: '你好世界');
  String _output = '';
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
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: '测试类型',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'embedding', child: Text('📊 Embedding')),
                DropdownMenuItem(value: 'llm', child: Text('💬 LLM')),
                DropdownMenuItem(value: 'stt', child: Text('🎤 STT')),
                DropdownMenuItem(value: 'tts', child: Text('🔊 TTS')),
                DropdownMenuItem(value: 'ocr', child: Text('📷 OCR')),
              ],
              onChanged: (v) => setState(() => _selectedType = v!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _inputController,
              decoration: const InputDecoration(
                labelText: '输入',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isRunning ? null : _runTest,
              icon: _isRunning
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow),
              label: Text(_isRunning ? '运行中...' : '运行测试'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(_output.isEmpty ? '结果将显示在这里' : _output),
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
      setState(() => _output = '请输入内容');
      return;
    }

    setState(() {
      _isRunning = true;
      _output = '处理中...';
    });

    try {
      final ml = ModelLoader.instance;

      switch (_selectedType) {
        case 'embedding':
          if (!ml.embedding.isLoaded) {
            setState(() => _output = '❌ 请先加载 Embedding 模型\n\n提示: Embedding 模型用于将文本转换为向量');
            return;
          }
          final result = await ml.embedding.getEmbedding(input);
          setState(() => _output = '✅ Embedding 结果:\n维度: ${result.dimension}\n前5个值: ${result.embedding.take(5).toList()}');
          break;

        case 'llm':
          if (!ml.llm.isLoaded) {
            setState(() => _output = '❌ 请先加载 LLM 模型\n\n提示: LLM 用于对话生成');
            return;
          }
          final result = await ml.llm.chat([ChatMessage.user(input)]);
          setState(() => _output = '✅ LLM 回复:\n$result');
          break;

        case 'stt':
          setState(() => _output = '🎤 STT 需要音频文件输入\n请先加载音频文件');
          break;

        case 'tts':
          setState(() => _output = '🔊 TTS 功能\n请先加载 TTS 模型');
          break;

        case 'ocr':
          setState(() => _output = '📷 OCR 功能\n请先加载图片');
          break;
      }
    } catch (e) {
      setState(() => _output = '❌ 错误: $e');
    } finally {
      setState(() => _isRunning = false);
    }
  }
}

/// 模型列表页面
class ModelsPage extends StatelessWidget {
  const ModelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ml = ModelLoader.instance;
    final models = ml.getSupportedModels();

    return Scaffold(
      appBar: AppBar(
        title: const Text('支持的模型'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: models.length,
        itemBuilder: (context, index) {
          final model = models[index];
          return Card(
            child: ListTile(
              leading: _getIcon(model.type),
              title: Text(model.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('格式: ${model.formats.join(", ")}'),
                  Text('最低内存: ${model.capability.minMemoryMB}MB'),
                ],
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // 显示模型详情
                _showModelInfo(context, model);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _getIcon(ModelType type) {
    switch (type) {
      case ModelType.llm:
        return const Text('💬', style: TextStyle(fontSize: 24));
      case ModelType.embedding:
        return const Text('📊', style: TextStyle(fontSize: 24));
      case ModelType.stt:
        return const Text('🎤', style: TextStyle(fontSize: 24));
      case ModelType.tts:
        return const Text('🔊', style: TextStyle(fontSize: 24));
      case ModelType.ocr:
        return const Text('📷', style: TextStyle(fontSize: 24));
      case ModelType.classification:
        return const Text('🏷️', style: TextStyle(fontSize: 24));
      case ModelType.custom:
        return const Text('📦', style: TextStyle(fontSize: 24));
    }
  }

  void _showModelInfo(BuildContext context, ModelDefinition model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(model.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('类型: ${model.type.displayName}'),
            Text('格式: ${model.formats.join(", ")}'),
            const SizedBox(height: 8),
            Text('最低内存: ${model.capability.minMemoryMB}MB'),
            Text('推荐内存: ${model.capability.recommendedMemoryMB}MB'),
            const SizedBox(height: 8),
            Text('支持量化: ${model.capability.supportsQuantization ? "✅" : "❌"}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
