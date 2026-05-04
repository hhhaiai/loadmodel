# ModelLoader 项目进展报告

**日期**: 2026-05-04
**版本**: v0.8 (最新提交: 2ee094f)

---

## 1. 当前质量基线

| 指标 | 状态 | 详情 |
|------|------|------|
| `flutter analyze` | ✅ 通过 | No issues found |
| `flutter test` | ✅ 通过 | 808/808 全绿 |
| 测试覆盖率 | ✅ 73.3% | 2501/3410 行 (超过 70% 目标) |
| Android 构建 | ✅ 通过 | `flutter build apk --debug` |
| iOS 构建 | ✅ 通过 | `flutter build ios --release --no-codesign` |

---

## 2. 已完成功能 (本次会话)

### 2.1 OCR 推理改进 (已提交: 2ee094f)

**Android/iOS 双端实现:**
- 置信度计算修正：直接使用模型输出的 softmax 概率，无需额外计算
- 图像反转检测：自动识别白底黑字/黑底白字并反转
- 清理调试日志

**测试页面增强:**
- OCR 模式自动加载默认测试图片
- 新增快速选择测试图片 chips (English, Model, Chinese 等)

**测试数据更新:**
- 更新 OCR 测试图片 (7 个 PNG 文件)
- 更新字符字典 (`ppocr_keys_v1.txt`)

---

## 3. 功能完成度总览

### 3.1 已实现功能 ✅

| 功能 | Android | iOS | 桌面 | 说明 |
|------|---------|-----|------|------|
| LLM 对话 | ✅ | ✅ | ✅ | llama.cpp 集成，结构化流式事件 |
| Embedding | ✅ | ✅ | ✅ | ONNX Runtime, 384 维输出 |
| OCR 识别 | ✅ | ✅ | ⚠️ | PaddleOCR PP-OCRv4, CTC 解码 |
| STT 语音识别 | ✅ | ✅ | ❌ | Whisper encoder+decoder, WAV 支持 |
| TTS 语音合成 | ✅ | ⚠️ | ❌ | Android: TextToSpeech, iOS: AVSpeechSynthesizer |
| 对话 UI | ✅ | ✅ | ✅ | ConversationTimeline + ContentBlock |
| 设置持久化 | ✅ | ✅ | ✅ | ConfigManager.uiSettings |
| 全局导航 | ✅ | ✅ | ✅ | AppNavigationController |

### 3.2 部分实现功能 ⚠️

| 功能 | 状态 | 缺口 |
|------|------|------|
| ModelManager | 部分实现 | 跨进程锁、完整解压校验、异常恢复 |
| RuntimeSelector | 部分实现 | 策略仍可细化 |
| 桌面端 OCR | 部分实现 | 需要 ONNX Runtime 桌面集成 |
| 桌面端 STT | 未实现 | 需要 Whisper.cpp 桌面集成 |
| iOS TTS | 基础实现 | 不支持文件输出，需 AVAudioEngine |

### 3.3 未实现功能 ❌

| 功能 | 优先级 | 说明 |
|------|--------|------|
| 多模态能力总线 | P2 | 统一文本/视觉/语音/向量/Agent 能力入口 |
| 插件化能力注册表 | P2 | 模型插件、能力插件、工具插件协议 |
| 本地 + 云混合推理 | P2 | 抽象层设计 |
| Agent Workflow | P3 | 任务编排、Tool 调用、自动化流程 |

---

## 4. 测试覆盖详情

### 4.1 测试文件分布

| 目录 | 测试数 | 覆盖重点 |
|------|--------|----------|
| `test/models/` | ~200 | 数据模型、序列化、目录 |
| `test/pages/` | ~250 | UI 页面、交互、状态 |
| `test/runtime/` | ~150 | 运行时接口、配置 |
| `test/core/` | ~100 | 配置管理、工具函数 |
| `test/widgets/` | ~100 | 通用组件、时间线 |

### 4.2 关键测试覆盖

- ✅ ConversationController: 空输入、LLM 未加载、并发 send、systemPrompt
- ✅ ModelLoaderException: 所有错误码、序列化/反序列化
- ✅ RuntimeManager: dispose/初始化路径
- ✅ ContentBlock: 所有类型渲染
- ✅ OCR/STT 配置: 序列化、边界条件

---

## 5. 代码架构

### 5.1 目录结构

```
lib/
├── app/                    # 应用壳层
│   ├── app_bootstrap.dart  # 启动引导
│   ├── app_shell.dart      # 主壳层
│   ├── model_loader_app.dart
│   └── navigation_controller.dart
├── core/                   # 核心逻辑
│   ├── config_manager.dart
│   ├── conversation_controller.dart
│   └── platform_utils.dart
├── models/                 # 数据模型
│   ├── content_block.dart
│   ├── conversation_entry.dart
│   ├── model_manifest.dart
│   └── llm_model_catalog.dart
├── pages/                  # UI 页面
│   ├── conversation_shell.dart
│   ├── test_page.dart
│   ├── model_load_page.dart
│   ├── status_page.dart
│   ├── settings_page.dart
│   └── models_page.dart
├── runtime/                # 运行时接口
│   ├── llm_runtime.dart
│   ├── onnx_runtime_flutter.dart
│   └── runtime_manager.dart
├── utils/                  # 工具函数
│   └── status_messages.dart
└── widgets/                # 通用组件
    └── conversation_timeline.dart
```

### 5.2 关键设计决策

1. **消息协议统一**: ConversationTimeline + ContentBlock
2. **原生桥接**: MethodChannel + llama.cpp JNI/Swift Bridge
3. **运行时分层**: LLM/ONNX/TTS 独立运行时
4. **导航架构**: AppNavigationController 全局导航

---

## 6. 下一步优先级

### P0 (必须先做)

1. **OCR 真机 E2E 验证**
   - 状态: 代码已实现，测试数据已生成
   - 待办: Android 真机测试图片输入 → 文字输出
   - 预计工作量: 1-2 小时

2. **STT 真机 E2E 验证**
   - 状态: 代码已实现，WAV 解析已支持
   - 待办: Android 真机测试音频输入 → 文字输出
   - 预计工作量: 1-2 小时

### P1 (MVP 完整度)

1. **扩展 E2E 场景**
   - 多轮对话质量验证
   - 跨功能联测 (LLM + OCR + STT)

2. **统一多能力结果消息结构**
   - 标准化所有能力的输出格式
   - 支持混合结果展示

3. **完善 ModelManager**
   - 跨进程锁
   - 完整解压校验
   - 异常恢复链路

### P2 (平台化能力)

1. **多模态能力总线**
2. **插件化注册协议**
3. **本地 + 云混合推理抽象层**
4. **补齐 Windows/Linux llama.cpp 集成**

---

## 7. 风险与限制

### 7.1 当前风险

1. **STT 推理质量**: 模型较小，识别准确率有限
2. **OCR 复杂场景**: 手写体、倾斜文本识别能力弱
3. **桌面端能力不完整**: Windows/Linux 缺少 OCR/STT/TTS
4. **长时间运行稳定性**: 未进行压力测试

### 7.2 已知限制

1. iOS Debug 包不稳定，只以 Release 为准
2. `adb input text` 不稳定，不能作为 Flutter 文本框验收手段
3. 小模型回复质量取决于模型规模和量化，不是 App 侧问题
4. iOS TTS 不支持直接文件输出

---

## 8. 总结

**当前状态**: `已达到开发验收级稳定，但未达到发布级稳定`

**关键成就**:
- 测试覆盖率从 72.0% 提升至 73.3%
- OCR 推理置信度计算修正
- 图像反转自动检测
- 测试页面 UX 改进

**下一步重点**:
1. 完成 OCR/STT 真机 E2E 验证
2. 扩展跨功能联测
3. 补齐桌面端能力

---

*报告生成时间: 2026-05-04*
*最新提交: 2ee094f (fix: improve OCR confidence calculation and add image inversion detection)*
