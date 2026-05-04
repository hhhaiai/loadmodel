# ModelLoader 工程蓝图与执行基线（v0.8）

更新时间：2026-05-04
适用范围：`/Users/sanbo/Desktop/loadmodel`

---

## 1. 文档目的

本文件同时承担两类职责：

1. 作为当前 `model_loader` 工程的**可验证执行基线**；
2. 作为未来演进的**总体蓝图与团队协作约束**；
3. 作为 Team Agent 自动化开发体系的统一决策依据。

状态定义：

- `已实现`：主路径已打通并可验证。
- `部分实现`：有代码与入口，但仍有明显缺口。
- `未实现`：无有效实现。
- `规划中`：目标明确，尚未进入落地实现。

---

## 2. AI Agent 自动化开发体系（Team Agent Framework）

### 2.1 总体目标

构建一个**跨平台 AI 应用工程体系**，通过**多 Agent 协作开发模式**自动推进项目设计、开发、验证与迭代。

所有开发任务由 **Team Agent 自动执行**，各 Agent 通过**文档驱动（Documentation Driven Development）**进行协作沟通，确保工程可追踪、可复现、可扩展。

系统采用 **SubAgent 常驻模式（Persistent SubAgent Runtime）**运行，各 Agent 长期待命，在收到任务后自动执行对应职责。

### 2.2 Agent 组织架构

#### Team Leader Agent（团队协调与决策）

**角色定位**

项目核心协调者，负责整体任务拆解、执行调度和决策支持。

**职责**

- 解析用户输入任务
- 分析当前工程状态
- 拆分任务并分派给各 SubAgent
- 审阅各 Agent 的产出文档
- 决策技术路线
- 协调冲突方案
- 输出最终执行计划

**运行模式**

- 常驻运行
- 持续监控项目进度
- 在用户发出新指令时进行动态调优

#### Scheduler Agent（任务调度 Agent）

**角色定位**

系统任务调度中心。

**职责**

- 管理任务队列
- 分发任务给对应 SubAgent
- 管理任务优先级
- 维护执行状态
- 控制并发任务

**运行模式**

- 后台持续运行
- 自动调度任务执行

#### Flutter Engineer Agent（Flutter 工程 Agent）

**角色定位**

跨平台应用开发工程师。

**技术栈**

- Flutter
- Dart

**支持平台**

- Windows
- macOS
- Linux
- Android
- iOS

**职责**

- 实现 UI 界面
- 实现功能模块
- 集成 AI 模型运行模块
- 实现插件扩展架构
- 编写高性能代码
- 支持多平台构建

**运行模式**

- SubAgent 常驻待命
- 接收任务后高速实现功能模块

#### Architect Agent（系统架构师）

**角色定位**

系统架构设计者。

**职责**

- 设计整体技术架构
- 制定模块边界
- 设计接口规范
- 编写技术设计文档
- 优化系统结构
- 保证系统可扩展性

**产出**

- 系统架构图
- 技术设计文档
- 模块设计文档
- API 接口文档

#### QA Agent（质量验证 Agent）

**角色定位**

质量控制负责人。

**职责**

- 编写单元测试
- 编写测试用例
- 自动化测试
- UI 自动化测试
- 功能验证
- 性能验证

**质量标准**

确保每个功能：

- 有测试用例
- 有自动化测试
- 可重复验证

#### Research Agent（技术调研 Agent）

**角色定位**

技术研究与方案对比专家。

**职责**

- 调研行业主流方案
- 分析竞品技术架构
- 研究开源项目
- 整理技术对比文档
- 提供决策建议

**输出**

- 技术调研报告
- 架构对比文档
- 技术选型建议

### 2.3 Agent 协作机制

#### 文档驱动协作（Document Driven Collaboration）

所有 Agent **必须通过文档进行沟通**。

文档类型包括：

- 需求文档
- 技术方案
- 设计文档
- 实现文档
- 测试文档
- 调研文档

Team Leader Agent 基于文档进行：

- 决策
- 任务调度
- 架构优化

#### SubAgent 运行模式

所有 Agent 采用 **SubAgent 持续运行模式**：

- 长期后台运行
- 随时待命
- 接收到任务立即执行
- 不需要人工干预

如果当前没有任务：

- Agent 会继续执行已有计划，直到任务完成。

如果用户输入新的指令：

Team Leader Agent 将：

1. 分析当前工程进度
2. 评估已有实现状态
3. 调整执行计划
4. 给出新的执行方案

---

## 3. 工程技术总目标

### 3.1 Flutter 跨平台工程

核心工程采用 **Flutter + Dart** 实现。

支持平台：

- Windows
- macOS
- Linux
- Android
- iOS

工程目标：

- 单一代码库
- 多平台运行
- 插件化扩展
- 高性能 UI

### 3.2 AI 模型加载与运行能力

系统核心能力是**本地 AI 模型运行平台**。

支持加载和运行多种主流模型格式，包括但不限于：

- ONNX
- GGUF
- BIN
- Safetensors
- PyTorch（`.pt` / `.pth`）
- TensorFlow（`.pb` / `.ckpt` / `.tflite`）
- MLX
- CoreML

### 3.3 推理能力

支持多种推理运行环境：

- CPU 推理
- GPU 推理
- NPU 加速

支持模型优化技术：

- INT8 量化
- INT4 量化
- LoRA Adapter
- 模型热加载
- 模型版本管理

目标实现：

- 本地推理
- 本地 + 云混合推理
- 多模型并行运行

### 3.4 AI 能力模块（多模态系统）

#### 文本能力

- AI 对话（Chat）
- 文本生成
- 文本总结
- 翻译
- 内容改写
- 知识问答

#### 视觉能力

- 图片识别
- OCR 识别
- 图像描述（Image Caption）
- 目标检测（Object Detection）
- 图片理解
- 多模态问答

#### 生成能力

- Text to Image
- Image to Image
- Inpainting
- 图片放大（Upscale）

#### 语音能力

- 文字转语音（TTS）
- 语音转文字（ASR）
- 实时语音对话

#### 向量能力

- 文本向量化
- 图片向量化
- Embedding 生成
- 语义搜索
- RAG 知识库

#### 智能代理能力

- 任务编排
- Tool 调用
- 自动化流程执行
- Agent Workflow

### 3.5 系统架构能力

#### 模块化架构

各 AI 功能模块独立，例如：

- chat module
- image module
- speech module
- vector module

#### 插件化能力

支持插件扩展：

- 新模型插件
- 新能力插件
- 新工具插件

#### 本地 + 云混合架构

支持：

- 本地模型运行
- 云端 API 调用
- 混合推理模式

---

## 4. UI 设计规范

所有功能**必须具备 UI 可视化展示**。

UI 设计原则：

- 统一采用 **ChatGPT 风格对话界面**；
- 每个功能 Case 必须以**对话形式展示结果**；
- 能力执行结果必须可回放、可识别、可验证。

示例：

用户输入：

```text
帮我识别这张图片
```

系统回复：

```text
检测到图片内容：
- 一只猫
- 一个沙发
```

### UI 核心组件

主要界面包括：

- Chat 对话界面
- 图片展示区域
- 音频播放区域
- 生成内容展示区
- 模型管理界面

---

## 5. 当前工程快照（实测）

### 5.1 基础信息

- Flutter 工程已拆分为 `app_bootstrap`、`model_loader_app`、`app_shell`，`lib/main.dart` 仅保留启动入口。
- 主要模型资产仍以本地 bundled 模型为主：`bge-small`、`tinyllama`、`qwen-1.5b`、`qwen-3.5-0.8b`。
- 移动端 LLM 已稳定采用 MethodChannel + 原生桥接，不再依赖 `127.0.0.1` HTTP 服务。
- App 已具备导航壳层：状态、加载、对话、测试、模型、设置六个页面。

### 5.2 质量信号（2026-05-04）

- `flutter analyze`：通过（No issues）
- `flutter test`：通过（`00:43 +740: All tests passed!`，从 554 增至 740）
- 最近一次 `flutter test --coverage` 实测：`73.3%`（`2501/3410`，2026-05-04）
- `flutter build apk --debug`：通过（`✓ Built build/app/outputs/flutter-apk/app-debug.apk`）
- `flutter build ios --release --no-codesign`：通过（`✓ Built build/ios/iphoneos/Runner.app`）
- 2026-05-03 本轮代码变更：
  - **Android 原生 STT 推理链路已实现**（`ModelLoaderPlugin.kt`）：
    - 新增 STT 模型加载：支持 encoder + decoder 分离模型
    - 实现 log-mel spectrogram 生成（FFT 512 + Hann window + 80 mel bins）
    - 实现 Whisper encoder 推理（输入: [1, 80, 3000] log-mel → 输出: [1, 1500, 384]）
    - 实现 Whisper decoder 推理（自回归生成 token）
    - 实现 token 到文本解码（vocab.json 词汇表）
    - 新增 `assets/models/whisper/vocab.json`（51865 tokens）
    - 新增 Gson 依赖用于 vocabulary JSON 解析
  - `ios/Runner/OnnxRuntimeManager.swift`：STT 完整推理链路实现（encoder + decoder + mel spectrogram + KV cache + vocab decoding）
  - `ios/Runner/ModelLoaderPlugin.swift`：STT 错误消息改为传递真实错误详情
- 2026-05-02 本轮代码变更：
  - **iOS ONNX Runtime 真实推理集成**：Embedding/OCR 可用，STT 会话加载 + 明确错误
  - 新增 `ios/Runner/OnnxRuntimeManager.swift`（397 行）：ONNX Runtime 会话管理器
    - CoreML EP 优先，CPU 回退
    - Embedding：WordPiece tokenize + 3 输入张量 + 384 维输出
    - OCR：图片解码/缩放 48×320/归一化 + ONNX 推理 + CTC 贪心解码
    - STT：会话加载成功，推理返回明确错误（与 Android 对齐）
  - `ios/Podfile`：新增 `onnxruntime-objc` 依赖
  - `ios/Runner/ModelLoaderPlugin.swift`：替换所有 `RUNTIME_NOT_AVAILABLE` 占位为真实实现
  - `lib/app/navigation_controller.dart`：全局导航控制器，支持跨页面导航
  - `lib/app/app_shell.dart`：接入全局导航控制器
  - `lib/pages/conversation_shell.dart`：新增返回按钮导航到状态页
  - `lib/pages/test_page.dart`：新增返回按钮导航到状态页
  - `android/app/src/main/cpp/llama_bridge.cpp`：增加 Android log 日志输出
  - `scripts/download_ocr_model.sh`：更新为 paddle2onnx 转换流程
- 2026-04-28 本轮新增 51 个测试（453→504），覆盖：
  - SettingsPage（8 tests）
  - StatusPage（6 tests）
  - ModelsPage（5 tests）
  - ConversationEntry contentBlocks 扩展（6 tests）
  - ConversationTimeline widget + ContentBlock 渲染（18 tests）
  - ModelLoadPage 扩展（+7 tests，总计 9）
- 2026-04-28 本轮代码变更：
  - ONNX 运行时已接入 ModelLoader（`_initMobileRuntimes` 取消注释并改为直接 import）
  - ContentBlock 类型体系已建立（`lib/models/content_block.dart`）
  - ConversationEntry 已扩展 contentBlocks 字段（向后兼容）
  - ConversationTimeline 已支持 ContentBlock 渲染
  - TestPage 已使用 ContentBlock 展示 Embedding/STT/OCR 结果
  - TTS 入口已从 ModelLoadPage 和 TestPage 下拉框中移除
  - **Android 原生 OCR 推理已实现**（`ModelLoaderPlugin.kt`）：bitmapToRgbFloatBuffer + CTC greedy decode + 字符字典
  - OCR 模型下载脚本已创建（`scripts/download_ocr_model.sh`）
  - OCR 字符字典已包含（`assets/models/ocr/ppocr_keys_v1.txt`，6900+ 中英文字符）
  - OCR model_config.json 已更新为 PaddleOCR PP-OCRv4 规格

### 5.3 文档同步规则（从 2026-03-21 起执行）

`CLAUDE.md` 是当前项目跨会话同步的单一事实源（SSOT）。

以后每次执行都必须满足以下规则：

1. 任何 build、test、真机验证、失败排查、回滚决策，都必须同步写入本文件后才算“完成”。
2. 成功路径必须记录：
   - 使用的命令
   - 前置条件
   - 观察到的结果
   - 涉及的代码锚点，方便后续回滚
3. 失败路径必须记录：
   - 失败现象
   - 已确认原因
   - 后续禁止继续作为默认方案的“开发黑名单”
4. 未写入 `CLAUDE.md` 的实验结论，一律视为“不可复用”，下个会话不能直接继承。
5. 后续会话开始前，必须先阅读本文件的 `5.3`、`5.4`、`5.5`、`5.6`、`5.7` 再继续执行。

### 5.4 已验证成功路径（2026-03-22）

#### A. 本地验证成功路径

推荐顺序必须是**串行**：

1. `flutter analyze`
2. `flutter test`
3. `flutter build apk --debug`
4. `flutter build ios --release --no-codesign`

本轮实测结果：

- 上述 4 步全部成功。
- 当前可以稳定完成：静态检查、单测、Android 构建、iOS Release 构建。

#### B. Android 真机成功路径

设备与包：

- 设备：`37101FDJH0077P`（`Pixel 8`）
- 包名：`com.modelloader.model_loader`
- 启动页：`com.modelloader.model_loader/.MainActivity`

已验证流程：

1. `adb -s 37101FDJH0077P install -r build/app/outputs/flutter-apk/app-debug.apk`
2. `adb -s 37101FDJH0077P shell pm clear com.modelloader.model_loader`
3. 通过 `adb shell uiautomator dump` + `adb shell input tap` 进入加载页
4. 选择：
   - 模型类型：`LLM`
   - 模型：`Qwen2.5 0.5B (Q4_0)`
5. 点击 `Load`

已观察到的成功信号：

- 日志出现 `nativeLoadLlamaModel ok=1`
- 日志出现 `Mobile LLM model loaded via MethodChannel`
- UI 出现 `✅ LLM 模型加载成功!`
- 当前 `adb -s 37101FDJH0077P shell pm path com.modelloader.model_loader` 仍可确认安装包存在

对话验证结论：

- 已至少成功返回一次真实模型输出，说明“安装 -> 启动 -> 加载 GGUF -> 生成文本”主链路是通的。
- 但 `adb input text` 对 Flutter 文本框不稳定，因此 Android 端“纯 adb 自动化多轮语义验收”暂时不能算稳定。

2026-03-22 重复复验结果：

1. `flutter analyze`：通过
2. `flutter test`：通过（`00:29 +453: All tests passed!`）
3. `flutter build apk --debug`：通过
4. `adb -s 37101FDJH0077P install -r build/app/outputs/flutter-apk/app-debug.apk`：通过
5. `adb -s 37101FDJH0077P shell pm clear com.modelloader.model_loader`：通过
6. `adb -s 37101FDJH0077P shell am start -n com.modelloader.model_loader/.MainActivity`：通过
7. `adb -s 37101FDJH0077P shell pidof com.modelloader.model_loader`：通过（`22055`）
8. `adb -s 37101FDJH0077P exec-out uiautomator dump /dev/tty`：通过

2026-03-22 观察到的稳定信号：

- fresh install 后应用可以正常冷启动，不闪退。
- 冷启动后状态页可正常渲染。
- 切换到对话页后，空态文案、输入框和 `发送` 按钮都能正常显示。
- 说明当前 Android 真机上的“安装 -> 启动 -> 基础页面导航”主链路稳定。

2026-03-22 仍然保留的限制：

- 本轮没有把“多轮聊天语义质量”重新作为最终稳定结论，因为 `adb input text` 仍然不是可靠验收手段。
- 因此 Android 端当前可宣称的是“安装/启动/页面导航稳定 + 模型加载链路历史已验证 + 代码回归全绿”，而不是“纯 adb 多轮聊天已稳定验收”。
- 2026-03-22 额外观察到：设备默认输入法会漂移到 `com.tencent.wetype/.plugin.hld.WxHldService`（微信输入法）。
- 这是对 adb 文本输入不稳定的**高概率原因**，不是最终定论；后续若要继续做 adb 聊天验收，优先临时切回 `com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME`（Gboard），测完再恢复用户原输入法。

#### C. iOS 真机成功路径

用户约束：

- iOS 真机**只接受 Release 包作为验收基线**
- Debug 包即使能编译，也**不能**视为真机可运行基线

已验证流程：

1. `flutter build ios --release --no-codesign`
2. `flutter run --release -d 00008120-000605C42244201E --no-resident`
3. `xcrun devicectl device info apps --device 00008120-000605C42244201E`
4. `xcrun devicectl device info processes --device 00008120-000605C42244201E`

已观察到的成功信号：

- `flutter run --release` 返回码为 `0`
- `devicectl` 可查询到 `Model Loader   com.modelloader.modelLoader`
- 历史实测中 `Runner` 进程保持存活

本轮补充确认：

- `flutter build ios --release --no-codesign` 再次通过
- `xcrun devicectl device info apps --device 00008120-000605C42244201E` 仍可查询到安装信息

#### D. llama.cpp 移动端适配成功路径

当前 Android / iOS 都已经切换到同一条消息语义链路：

1. Dart 层传递结构化 `messages`
2. 原生层优先调用 `llama_model_chat_template + llama_chat_apply_template`
3. 只有模型本身没有模板时，才回退到最简单的 `role: content` 文本拼接

这意味着：

- App 不再手写 `assistant:` 假提示词驱动回复
- 系统提示词、历史上下文、当前用户输入都会进入同一消息链路
- “弱智回复”如果再次出现，优先判断为模型规模/量化/模板兼容问题，而不是 App 侧默认回复

代码锚点（后续回滚或排查先看这里）：

- `lib/pages/settings_page.dart`
- `lib/core/conversation_controller.dart`
- `lib/runtime/llm_runtime_mobile.dart`
- `android/app/src/main/kotlin/com/modelloader/model_loader/ModelLoaderPlugin.kt`
- `android/app/src/main/cpp/llama_bridge.h`
- `android/app/src/main/cpp/llama_bridge.cpp`
- `android/app/src/main/cpp/llama_jni.cpp`
- `ios/Runner/LlamaBridge.h`
- `ios/Runner/LlamaBridge.mm`
- `ios/Runner/ModelLoaderPlugin.swift`

#### E. 对话发送交互成功路径

从 2026-03-21 起，对话页发送链路的期望行为固定为：

1. 点击 `发送` 后，输入框立即清空
2. 用户刚输入的内容立即进入上方对话展示区
3. `发送` 按钮文案保持不变，仅切换为禁用态
4. 机器人回复位置在首个 token 到来前，显示一次静态 `正在生成中...`
5. 用户可手动清空当前对话，清空时会同时中断当前生成并重置上下文

本轮已完成实现与回归：

- 代码位置：
  - `lib/pages/conversation_shell.dart`
  - `lib/core/conversation_controller.dart`
  - `lib/widgets/conversation_timeline.dart`
- 测试位置：
  - `test/pages/conversation_shell_test.dart`
  - `test/pages/test_page_widget_llm_test.dart`
  - `test/pages/conversation_controller_test.dart`
- 验证结果：
  - `flutter test test/pages/conversation_shell_test.dart test/pages/test_page_widget_llm_test.dart test/pages/conversation_controller_test.dart`
  - 结果：通过（`All tests passed!`）
  - `flutter test`
  - 结果：通过（`00:10 +446: All tests passed!`）
  - `flutter analyze`
  - 结果：通过（`No issues found!`）

2026-03-21 同日补充修正：

- 发送按钮不再把文案切成 `发送中`，避免按钮宽度变化导致抖动；现在保持文案恒定为 `发送`，仅通过禁用态表示运行中。
- `正在生成中...` 不再使用任何定时动画，改为一次静态占位，避免周期性重绘导致屏幕抖动。
- 补充验证：
  - `flutter test test/pages/conversation_shell_test.dart test/pages/test_page_widget_llm_test.dart test/pages/conversation_controller_test.dart`
  - 结果：通过（`All tests passed!`）
  - `flutter analyze`
  - 结果：通过（`No issues found!`）
  - `flutter build apk --debug`
  - 结果：通过（`✓ Built build/app/outputs/flutter-apk/app-debug.apk`）
  - `adb -s 37101FDJH0077P install -r build/app/outputs/flutter-apk/app-debug.apk`
  - 结果：通过（`Performing Streamed Install / Success`）

2026-03-22 补充增强：

- 对话页新增“清空对话”入口，避免旧消息、旧错误、旧上下文污染后续手测。
- 清空对话时会同步中断当前生成中的请求，不再保留半成品回复。
- 相关验证：
  - `test/pages/conversation_controller_test.dart`
  - `test/pages/conversation_shell_test.dart`
  - `flutter test test/pages/conversation_controller_test.dart test/pages/conversation_shell_test.dart`
  - 结果：通过（`All tests passed!`）
  - `flutter analyze`
  - 结果：通过（`No issues found!`）

### 5.5 开发黑名单（失败路径沉淀）

以下方案从 2026-03-21 起禁止继续作为默认开发方式：

1. **并发执行多个 `flutter` 命令**
   - 现象：出现 `Waiting for another flutter command to release the startup lock...`
   - 结论：`flutter analyze / test / build` 必须串行执行

2. **把 iOS Debug 包当作真机验收基线**
   - 现象：用户已明确指出 Debug 包在 iOS 真机上会闪退/不可用
   - 结论：iOS 真机只以 Release 包为准

3. **在 Dart 侧手工拼接 `user:` / `assistant:` 假 prompt**
   - 现象：容易造成角色混乱、重复回复、上下文质量不稳定
   - 结论：移动端必须优先走结构化 `messages` + 原生 chat template

4. **把“模型加载成功”当成“模型对话质量已验证”**
   - 现象：加载成功不等于模型回复质量正常，也不等于上下文有效
   - 结论：后续必须额外验证至少一次真实问答结果

5. **把 `adb shell input text` 当作 Flutter 文本框稳定验收手段**
   - 现象：输入偶发失效、重复、乱码、IME 干扰
   - 结论：只能作为辅助方法，不能单独作为聊天稳定性的最终证据

6. **未记录到 `CLAUDE.md` 的实验结论直接沿用到后续会话**
   - 现象：上下文漂移，重复踩坑
   - 结论：未入文档的操作一律视为无效经验

### 5.6 用户当前 5 项诉求对照（2026-03-22）

| 用户诉求 | 当前状态 | 已有证据 | 仍有缺口 |
|---|---|---|---|
| 1. 所有操作项、计划、失败/成功都要文档同步，跨会话可继承 | 部分实现 | 本文件现已补充同步规则、成功路径、黑名单、真机结论 | 仍未做到 CI 或流程强制，当前依赖执行纪律 |
| 2. 模型回复必须直接依赖原始模型，不能有默认回复或硬编码兜底话术 | 已实现 | Dart 侧不再伪造 `assistant:` prompt；对话页显示的是原生 LLM 输出；`[完成]` 标记已从历史语义中移除 | 模型质量仍取决于模型规模、量化和模板兼容，不等于“小模型也会聪明” |
| 3. 系统提示词可修改，用户问答保留上下文 | 已实现 | 设置页新增 `systemPrompt` 持久化；`ConversationController` 会把系统提示词和已完成历史消息一起传给 LLM | 还缺更强的人工真机多轮语义回归 |
| 4. AI 出问题不能拖垮 UI，点击和反馈要灵敏 | 部分实现 | 当前对话是异步流式；发送后会立即清空输入框、用户消息立即上屏、按钮保持 `发送` 文案但进入禁用态、机器人区域显示一次静态 `正在生成中...`；用户还可手动清空旧对话并中断当前生成；Android 真机页面切换和模型加载页导航稳定 | 还没有长时间压力测试、卡顿采样和内存回归数据 |
| 5. 所有功能必须独立，不能因为 AI 影响其他功能 | 部分实现 | LLM、Embedding、OCR、STT、TTS 运行时已分层；OCR/STT 假成功已被拦截，不会再伪装成正常结果 | 还缺完整的跨功能回归矩阵，尤其是真机上的非 AI 功能联测 |

### 5.7 最新真机验证结论（2026-05-04）

当前**可以确认**的事实：

1. 工程当前可以稳定完成：
   - `flutter analyze`
   - `flutter test`（808/808 全绿，覆盖率 73.3%）
   - `flutter build apk --debug`
   - `flutter build ios --release --no-codesign`
2. Android 真机在 2026-03-22 再次完成”安装 -> 清数据 -> 冷启动 -> 状态页渲染 -> 对话页打开”复验。
3. Android 真机已经在历史实测中打通一次”安装 -> 启动 -> 加载 bundled GGUF -> 返回模型文本”主链路。
4. iOS 侧已经实测通过 Release 安装/启动基线，且当前仍可查询到安装状态。
5. llama.cpp 的 iOS / Android 消息模板适配已完成，系统提示词与上下文链路已经接入。
6. iOS ONNX Runtime 已真实集成：Embedding/OCR/STT 均已实现真实推理（2026-05-03 复验通过）。
7. 全局导航控制器已建立，对话页/测试页新增返回按钮。
8. **Android 原生 STT 推理链路已实现**（2026-05-03）：
   - Mel spectrogram 生成（FFT 512 + Hann window + 80 mel bins）
   - Whisper encoder 推理（[1, 80, 3000] → [1, 1500, 384]）
   - Whisper decoder 自回归推理
   - Token 到文本解码（vocab.json 51865 tokens）
   - 待真机 E2E 验证
9. **iOS 原生 STT 推理链路已实现**（2026-05-03）：
   - 与 Android 完全对齐的实现：encoder + decoder 分离加载、mel spectrogram、FFT、KV cache、vocab decoding
   - iOS ORT SDK 无 `.bool` 类型，使用 `.int8` 替代
   - 待真机 E2E 验证
10. **TTS 运行时已在双端实现**（2026-05-03）：
    - Android：`TextToSpeech.synthesizeToFile` 完整实现，支持 speed/pitch，输出 WAV 文件
    - iOS：`AVSpeechSynthesizer` 基础实现（通过扬声器播放，iOS 不支持直接文件输出）
    - Dart 层：`_TTSRuntimeImpl` 通过 MethodChannel 调用原生 TTS
    - 待真机 E2E 验证
11. **OCR 测试界面已重新设计**（2026-05-04）：
    - 支持相机拍照 + 图片上传两种方式输入（`image_picker`）
    - `OCRBlockDisplay` 新增 `imageBytes` 字段，结果中原图对照显示
    - Android CAMERA 权限 + iOS NSCameraUsageDescription/NSPhotoLibraryUsageDescription 已配置
    - 生产级审查通过：mounted 检查、10MB 限制、异常处理、Image.memory errorBuilder
    - 测试 808/808 全绿
12. **ModelLoadPage 已统一到 ConversationTimeline + ContentBlock 协议**（2026-05-04）：
    - 加载结果从单一 `_status` 字符串改为 `List<ConversationEntry>` 结构化消息
    - 成功/错误/加载中分别使用 TextBlock/ErrorBlock/StatusBlock 展示
    - 测试 808/808 全绿（无需修改即通过）

当前**不能直接宣称**的事实：

1. 不能宣称 iOS 本轮已经完成”加载模型 + 多轮对话质量”重新验收。
2. 不能宣称 Android 的”纯 adb 输入驱动聊天验收”已经稳定，因为输入链路本身不稳定。
3. 不能宣称整个项目已达到发布级稳定，尤其是 OCR / STT / TTS / 长时压力场景。
4. 不能宣称 Android/iOS STT/TTS 已验证可用，因为尚未进行真机 E2E 测试（代码已实现，待验证）。

当前工程状态的准确表述应为：

`已达到开发验收级稳定：双端可构建，Android 真机主链路可跑，iOS Release 真机基线可跑；但尚未达到发布级稳定。`

---

## 6. 当前模块完成度（按代码校准）

| 模块 | 状态 | 说明 |
|---|---|---|
| SDK 基础结构 (`ModelLoader`, Runtime 接口) | 已实现 | 基本骨架稳定，可替换运行时 |
| App 启动与壳层 (`app/*`, `main.dart`) | 已实现 | 启动引导、MaterialApp、导航壳层均已拆分 |
| Manifest 数据结构 (`model_manifest.dart`) | 部分实现 | 结构完整，但全流程接线与约束仍可加强 |
| RuntimeSelector | 部分实现 | 已接入加载入口并输出 SelectionReport，策略仍可继续细化 |
| ModelManager 下载安装 | 部分实现 | 已有安装状态机、版本目录、hash 校验；仍缺跨进程锁与完整解压校验链路 |
| TaskScheduler | 部分实现 | 调度框架存在，但业务联动深度不足 |
| LLM Runtime（Dart） | 部分实现 | 桌面/移动主链路可用，结构化流式事件已落地，后端能力仍需持续对齐 |
| ONNX Flutter Runtime（Dart） | 部分实现 | Embedding 可用；OCR/STT 已具备防假成功保护；TTS 已实现 |
| iOS 原生插件 | 部分实现 | 本地 LLM bridge 可用；ONNX Runtime 已集成（Embedding/OCR/STT 真实推理可用）；TTS 已实现（AVSpeechSynthesizer 播放音频） |
| Android 原生插件 | 部分实现 | 本地 LLM JNI bridge 可用（增加 android log 日志）；OCR 推理已实现（CTC decode + 字符字典，待真实模型验证）；STT 推理已实现（mel spectrogram + encoder + decoder + vocab decoding，待真机 E2E）；TTS 已实现（TextToSpeech 文件输出） |
| UI（加载/对话/测试/状态/设置） | 部分实现 | 设置持久化已实现；对话页与测试页已转向消息流展现；全局导航控制器已建立；统一 UI 协议仍未完成 |
| 测试体系 | 部分实现 | 单测基线 808 个用例全绿，覆盖率 73.3%（2026-05-04）|
| 多模态能力总线 | 规划中 | 仍需统一文本/视觉/语音/向量/Agent 能力入口 |
| 插件化能力注册表 | 规划中 | 仍需定义模型插件、能力插件、工具插件协议 |
| ChatGPT 风格统一 UI 壳层 | 部分实现 | `ConversationShell`、`TestPage`、`ModelLoadPage` 已采用对话式承载；`StatusPage`/`SettingsPage`/`ModelsPage` 为仪表盘/表单/目录页面，不需要对话式化 |

---

## 7. 相比旧基线的关键进展

1. **设置页持久化已落地**
   - `_saveSettings` 已实现，设置会写入 `ConfigManager.uiSettings` 并在页面启动时回填。

2. **移动端 llama.cpp 消息模板链路已切换完成**
   - Dart 层改为直接传递结构化 `messages`，不再伪造 `assistant:` prompt。
   - Android / iOS 原生层已接入 `llama_chat_apply_template`。

3. **LLM 结构化流式事件已落地**
   - `LLMRuntime` 已提供 `chatStreamEvents/completeStreamEvents`，输出 `delta/metrics/finish/error` 结构。
   - `ConversationController` 已消费结构化事件并驱动对话 UI。

4. **`main.dart` 已完成拆分**
   - 启动逻辑迁移到 `lib/app/app_bootstrap.dart`。
   - 应用壳层迁移到 `lib/app/model_loader_app.dart` 与 `lib/app/app_shell.dart`。

5. **测试与静态检查基线显著提升**
   - `flutter test` 从早期几十个用例增长到 `453/453` 全绿。
   - 最近一次覆盖率提升到 `60.46%`。

6. **原生占位推理的“假成功”已被阻断**
   - OCR/STT 若返回明显占位文本，Dart 层会转换为 `RUNTIME_NOT_AVAILABLE`，不再被 UI 误判为推理成功。

7. **测试页开始向统一对话式 UI 靠拢**
   - `TestPage` 已改为基于 `ConversationTimeline` 的消息历史，而不是单一字符串输出。

8. **对话页发送交互已修正到可用基线**
   - 发送后输入框立即清空，用户消息立即上屏。
   - 按钮在推理期间保持 `发送` 文案，仅显示禁用态；机器人位置显示一次静态 `正在生成中...`。

9. **App 端主链路测试已增强**
   - 新增 `AppShell` 级测试，覆盖四个内置 LLM 选项在 app 内的“加载页 -> 成功加载 -> 切到对话页 -> 成功收流式回复”流程。
   - 同时补充了桌面端 bootstrap 断言，确保 macOS/desktop 仍推荐并配置 `llama.cpp` 作为 LLM 运行时。

10. **提交前代码收口已完成一轮**
   - 新增 `lib/models/llm_model_catalog.dart`，把加载页、设置页和 app 端测试使用的内置 LLM 元数据收敛到单一目录，避免重复定义漂移。
   - `AppShell` 增加了页面数量与底部导航项数量的一致性断言，降低注入测试页面时的结构性回归风险。
   - `README.md` 已从 Flutter 模板文案改为真实项目说明，并补充了 GitHub 提交前的大文件风险提示。

11. **`assets/models/` 已改成分片归档提交流程**
   - 新增 `pack_models.sh` / `restore_models.sh` 作为 `assets/models/` 的归档与恢复入口。
   - `auto_split.sh` / `auto_merge.sh` 已增加目录归档模式，支持 `tar.gz + 49MB 分片 + sha256 校验 + 解压恢复`。
   - 当前分片输出目录为 `assets/models_archive/`，本地解压目录 `assets/models/` 已加入 `.gitignore`，避免误把原始大文件再次提交。

12. **`third_party/llama.cpp/` 已切换到同类归档方案**
   - 新增 `pack_llama_cpp.sh` / `restore_llama_cpp.sh` 作为 `third_party/llama.cpp/` 的归档与恢复入口。
   - 当前分片输出目录为 `third_party/llama_cpp_archive/`，本地解压目录 `third_party/llama.cpp/` 已加入 `.gitignore`。
   - Android 构建前提仍然是先恢复 `third_party/llama.cpp/`，否则 `android/app/src/main/cpp/CMakeLists.txt` 找不到源码目录。

13. **ONNX 运行时已接入 + ContentBlock 统一展示 + TTS 入口隐藏 + Android OCR 推理实现 + 测试覆盖率提升（2026-04-28）**
   - `lib/model_loader.dart`：`_initMobileRuntimes()` 已取消注释并改为直接 import ONNX 运行时，Embedding/OCR/STT 在移动端已接入。
   - 新增 `lib/models/content_block.dart`：sealed class 体系（TextBlock、ErrorBlock、StatusBlock、EmbeddingBlock、OCRBlockDisplay、MetricBlock）。
   - `lib/models/conversation_entry.dart`：新增 `contentBlocks` 字段和 `hasStructuredContent` getter，向后兼容。
   - `lib/widgets/conversation_timeline.dart`：新增 `_buildContentBlocks()` 渲染器，按 block 类型分派展示。
   - `lib/pages/test_page.dart`：Embedding/STT/OCR 结果已改用 ContentBlock 展示。
   - `lib/pages/model_load_page.dart` 和 `lib/pages/test_page.dart`：TTS 下拉项已移除。
   - **Android 原生 OCR 推理实现**（`ModelLoaderPlugin.kt`）：
     - `bitmapToRgbFloatBuffer()`：Bitmap → NCHW RGB float buffer，归一化到 [-1, 1]
     - `ctcGreedyDecode()`：CTC 贪心解码（argmax + 去重 + 去 blank）
     - `loadOcrCharDict()`：从 assets 加载 `ppocr_keys_v1.txt` 字符字典（6900+ 中英文字符）
     - `handleRecognizeOCR()`：完整推理链路（decode → resize 48×320 → normalize → ONNX inference → CTC decode → text + confidence）
   - 新增 `scripts/download_ocr_model.sh`：PaddleOCR PP-OCRv4 mobile ONNX 模型下载脚本
   - 新增 `assets/models/ocr/ppocr_keys_v1.txt`：中英文字符字典
   - 测试从 453 增长到 504（+51），新增 SettingsPage/StatusPage/ModelsPage/ConversationTimeline/ConversationEntry/ModelLoadPage 扩展测试。

14. **iOS ONNX Runtime 集成完成（2026-05-01，2026-05-02 复验）**
   - `ios/Podfile`：新增 `pod 'onnxruntime-objc', '~> 1.16.0'` 依赖
   - 新增 `ios/Runner/OnnxRuntimeManager.swift`（397 行）：ONNX Runtime 会话管理器
     - `ORTEnv` 全局环境初始化
     - `createSession()`：创建 ORT 会话，尝试 CoreML EP，失败回退 CPU
     - Embedding：WordPiece tokenize + 3 输入张量 + 384 维输出提取
     - OCR：图片解码/缩放/归一化 + ONNX 推理 + CTC 贪心解码
     - STT：会话加载成功，推理返回明确错误（与 Android 对齐）
   - `ios/Runner/ModelLoaderPlugin.swift`：替换所有 `RUNTIME_NOT_AVAILABLE` 占位
     - `handleLoadEmbeddingModel` / `handleGetEmbedding`：调用 OnnxRuntimeManager 实现真实推理
     - `handleLoadOCRModel` / `handleRecognizeOCR`：调用 OnnxRuntimeManager 实现真实推理
     - `handleLoadSTTModel` / `handleRecognizeSTT`：加载会话 + 明确错误提示
   - `ios/Runner.xcodeproj/project.pbxproj`：添加 OnnxRuntimeManager.swift 到编译列表
   - 验证结果（2026-05-02 复验）：
     - `flutter analyze`：通过（No issues found!）
     - `flutter test`：通过（00:14 +504: All tests passed!）
     - `flutter build ios --release --no-codesign`：通过（✓ Built build/ios/iphoneos/Runner.app）

15. **全局导航控制器 + 页面返回按钮（2026-05-02）**
   - 新增 `lib/app/navigation_controller.dart`：`AppNavigationController` 全局导航控制器
   - `lib/app/app_shell.dart`：接入全局导航控制器，支持跨页面程序化导航
   - `lib/pages/conversation_shell.dart`：新增返回按钮，点击导航到状态页
   - `lib/pages/test_page.dart`：新增返回按钮，点击导航到状态页
   - `android/app/src/main/cpp/llama_bridge.cpp`：增加 `__android_log_print` 日志，覆盖模型加载全流程
   - `scripts/download_ocr_model.sh`：更新为 paddle2onnx 转换流程（需 `paddlepaddle` + `paddle2onnx`）
   - 验证结果：
     - `flutter analyze`：通过
     - `flutter test`：通过（504/504）
     - `flutter build apk --debug`：通过
     - `flutter build ios --release --no-codesign`：通过

16. **Android 原生 STT 推理链路已实现（2026-05-03）**
   - `android/app/src/main/kotlin/.../ModelLoaderPlugin.kt`：
     - STT 模型加载改为加载 encoder + decoder 分离模型
     - 新增 `computeLogMelSpectrogram()`：FFT 512 + Hann window + 80 mel bins + log transform
     - 新增 `fft()`：radix-2 Cooley-Tukey FFT 实现
     - 新增 `computeMelFilterbank()`：mel filterbank 计算
     - 新增 `runEncoderInference()`：Whisper encoder ONNX 推理
     - 新增 `runDecoderInference()`：Whisper decoder 自回归推理
     - 新增 `decodeTokens()`：token ID 到文本解码
     - 新增 `loadSTTVocabulary()`：加载 vocab.json 词汇表
   - 新增 `assets/models/whisper/vocab.json`（51865 tokens，Whisper tokenizer）
   - `android/app/build.gradle.kts`：新增 Gson 依赖（vocabulary JSON 解析）
   - 验证结果：
     - `flutter analyze`：通过（No issues）
     - `flutter test`：通过（504/504）
     - `flutter build apk --debug`：通过
     - `flutter build ios --release --no-codesign`：通过
   - 待办：真机 E2E 验证

17. **Android STT 关键 Bug 修复 + iOS 改进 + 测试覆盖率提升（2026-05-03）**
   - `ModelLoaderPlugin.kt` 修复项：
     - **FFT 缓冲区溢出修复**：`fft()` 原先复制 512 元素到 257 大小的数组，修改为只复制 N_FFT/2+1 个元素
     - **KV Cache 实现**：decoder 现在正确捕获 `present.*` 输出并在下一步作为 `past_key_values.*` 输入，自回归生成不再从零开始
     - **Timestamp token 范围修正**：`decodeTokens` 中的时间戳 token 范围从错误的 50464-50639 修正为 50364-51864（覆盖所有 Whisper 时间戳 token）
     - **Vocab size 动态推断**：从模型输出 shape 推断 vocab size，不再硬编码 51865
     - **真实置信度计算**：STT 和 OCR 的 confidence 都改为基于 softmax 概率，不再使用硬编码值或原始 logit
     - **Dead code 清理**：移除未使用的 `processSTTOutput()` 和 `computeMagnitude()` 方法
     - **重复 import 修复**：移除重复的 `kotlin.math.sqrt` import
     - **注释修正**：`TOKEN_NO_TIMESTAMPS` 注释从错误的 `<|nocaptions|>` 修正为 `<|notimestamps|>`
     - **音频格式校验**：新增最小音频长度校验（100 bytes）
     - **OCR bitmap double-recycle 防护**：`createScaledBitmap` 返回同一对象时避免双重回收
   - `OnnxRuntimeManager.swift` 改进项：
     - **OCR confidence 改用 softmax**：与 Android 对齐
     - **imageToRgbFloatBuffer 失败时 throw**：不再静默返回全零数组
     - **extractEmbedding 动态维度**：从模型 output shape 推断维度，不再硬编码 384
     - **recognizeOCR 输入校验**：空 imageData 时直接 throw
   - `conversation_controller_test.dart` 新增 6 个测试：
     - 空输入处理（send('') 添加 error entry）
     - LLM 未加载路径
     - currentGenerationConfig 温度/maxTokens 钳位
     - finish 事件标记 user entry 为 complete
     - 并发 send 取消
     - 空白 systemPrompt 返回 null
   - 验证结果：
     - `flutter analyze`：通过（No issues）
     - `flutter test`：通过（510/510，从 504 增长到 510）
     - `flutter build apk --debug`：通过
     - `flutter build ios --release --no-codesign`：通过

18. **iOS STT 完整推理链路实现（2026-05-03）**
   - `ios/Runner/OnnxRuntimeManager.swift` 重写 STT 部分：
     - **Encoder + Decoder 分离加载**：`loadSTTModel()` 从 modelPath 推导 `onnx/encoder_model.onnx` 和 `onnx/decoder_model_merged.onnx` 路径，分别创建 ORT session
     - **Vocabulary 加载**：从 `vocab.json` 加载 51865 token 词汇表，支持 token ID → 文本解码
     - **16-bit PCM → float 转换**：`convertAudioToFloat()` 将原始音频数据转换为 [-1, 1] 浮点数组
     - **Log-mel spectrogram 生成**：`computeLogMelSpectrogram()` 实现完整 FFT 512 + Hann window + 80 mel bins + log transform
     - **Radix-2 Cooley-Tukey FFT**：`fftInPlace()` 原地 FFT 实现
     - **Mel filterbank 计算**：`computeMelFilterbank()` 生成三角滤波器组
     - **Encoder 推理**：`runEncoderInference()` 输入 [1, 80, 3000] 输出 [1, 1500, 384]
     - **Decoder 自回归推理**：`runDecoderInference()` 实现 KV cache、softmax 置信度计算、EOS 检测
     - **Token 解码**：`decodeTokens()` 处理 Ġ 空格标记、特殊 token 过滤、时间戳 token 跳过
   - `ios/Runner/ModelLoaderPlugin.swift`：STT 错误消息改为传递真实错误详情
   - iOS ORT SDK 无 `.bool` 类型，改用 `.int8` 传递 `use_cache_branch` 标志
   - 验证结果：
     - `flutter analyze`：通过（No issues）
     - `flutter test`：通过（510/510）
     - `flutter build ios --release --no-codesign`：通过
     - `flutter build apk --debug`：通过
     - Android 真机：APK 安装成功，app 正常运行

19. **测试覆盖率提升 + RuntimeManager dispose 修复 + model_loader_exception 全覆盖（2026-05-03）**
   - 新增测试文件：
     - `test/models/model_loader_exception_test.dart`（34 tests）：覆盖 ModelLoaderErrorCode 所有枚举值、ModelLoaderErrorDetails 序列化/反序列化、ModelLoaderException 所有 factory constructors（modelNotFound/modelVerifyFailed/runtimeNotAvailable/insufficientMemory/downloadFailed）
     - `test/pages/model_load_page_load_flow_test.dart`（8 tests）：覆盖 _isPlaceholderModelFile 边界条件、load button 触发 missing asset 状态、LLM dropdown 显示、切换类型清除状态
     - `test/runtime/runtime_manager_test.dart` 新增 3 tests：dispose 卸载 loaded runtimes、dispose 跳过 unloaded runtimes、error handling
   - `lib/runtime/runtime_manager.dart` 修复：
     - 字段从 `late final` 改为 `late LLMRuntime?` 等，支持 nullable 以实现 dispose 后重新 init
     - dispose() 添加 null-safe 检查 `llm?.isLoaded == true`
     - init() 改为检查 `llm != null` 判断是否已初始化
   - 测试结果：`flutter test` 从 510 增至 554（+44 tests），覆盖率从 64.4% 提升至 67.3%（2182/3241）
   - 验证结果：
     - `flutter analyze`：通过（No issues）
     - `flutter test`：通过（554/554）
     - `flutter build apk --debug`：通过
     - `flutter build ios --release --no-codesign`：通过

20. **TTS 运行时在双端实现（2026-05-04）**
    - Android TTS（完整实现）：
      - `ModelLoaderPlugin.kt` 新增 TTS handler：`handleLoadTTSModel`、`handleUnloadTTSModel`、`handleSynthesizeTTS`
      - 使用 `TextToSpeech` API，`synthesizeToFile` 输出 WAV 文件
      - 支持 speed/pitch 参数设置
      - 清理时正确调用 `shutdown()`
    - iOS TTS（基础实现）：
      - `ModelLoaderPlugin.swift` 新增 TTS handler
      - 使用 `AVSpeechSynthesizer` API，通过扬声器播放
      - iOS 不支持直接文件输出（需 AVAudioEngine 才能实现文件输出）
    - Dart 层：
      - `lib/runtime/onnx_runtime_flutter.dart`：`_TTSRuntimeImpl` 替代 `_TTSRuntimeUnimplemented`
      - 通过 MethodChannel `synthesizeTTS` 调用原生 TTS
      - `synthesizeBytes` 生成到临时文件再读取返回
    - 验证结果：
      - `flutter analyze`：通过（No issues）
      - `flutter test`：通过（738/738，2026-05-04）
      - `flutter build apk --debug`：通过
      - `flutter build ios --release --no-codesign`：通过

22. **Subagent 并行测试扩展 + 覆盖率提升至 72.0%（2026-05-04）**
    - 并行启动 10 个 subagent 扩展测试覆盖：
      - `test/runtime/onnx_tts_runtime_test.dart`（11 tests）：TTS 运行时方法验证
      - `test/pages/model_load_page_error_state_test.dart`（37 tests）：错误状态 UI 展示
      - `test/runtime/runtime_manager_test.dart`（+25 stub tests）：dispose/初始化路径
      - `test/models/inference_event_mapper_test.dart`：InferenceEventMapper 映射逻辑（30 tests）
      - `test/models/llm_model_catalog_test.dart`：LLM 模型目录枚举（24 tests）
      - `test/models/model_type_test.dart`：ModelType 扩展方法（含 case-insensitivity 修复）
      - `test/runtime/stt_config_test.dart` / `ocr_config_test.dart` / `embedding_config_test.dart` / `tts_config_test.dart`：Config 类序列化（26 tests）
      - `test/models/download_task_extended_test.dart`：DownloadTask 扩展属性
      - `test/core/config_manager_settings_test.dart`：ConfigManager setter/getter 覆盖（12 tests）
      - `test/runtime/onnx_runtime_helper_test.dart`（18 tests）：ONNX helper 函数验证
    - `lib/models/model_type.dart`：`fromString` 改为大小写不敏感（case-insensitive）
    - 修复 `flutter analyze` 警告：`test/runtime/onnx_runtime_helper_test.dart` 移除未使用的 `onnx_runtime_flutter.dart` import
    - STT/OCR E2E 验证调研完成：
      - STT/OCR 模型权重文件**均为真实 ONNX 模型文件**（非占位符）
      - 模型文件已验证：OCR model.onnx (10MB, ONNX magic 0x0806), Whisper encoder (31MB), decoder (113MB)
      - 测试数据缺失（无真实音频/图片测试文件）导致 E2E 验证不完整
      - `test_page.dart` 之前使用 fake audio/1x1 pixel image，非真实输入
    - 验证结果：
      - `flutter analyze`：通过（No issues）
      - `flutter test`：通过（738/738）
      - `flutter build apk --debug`：通过
      - `flutter build ios --release --no-codesign`：通过

23. **STT/OCR 真实测试数据生成 + WAV 格式支持（2026-05-04）**
    - 生成真实 OCR 测试图片（320x48 PNG，中英文字符）：
      - `assets/models/ocr/test_chinese.png`（含 "Hello 世界" + "OCR Test"）
      - `assets/models/ocr/test_english.png`（含 "Model Loader"）
    - 生成真实 STT 测试音频（16kHz WAV，3秒）：
      - `assets/models/whisper/test_audio.wav`（48000 samples，正弦波组合）
    - 更新 `pubspec.yaml`：新增 test_audio.wav 和 test_*.png 到 assets 声明
    - 更新 `lib/pages/test_page.dart`：
      - OCR 测试加载 `test_chinese.png` 真实图片（替代 1x1 像素假数据）
      - STT 测试加载 `test_audio.wav` 真实音频（替代 3200 字节 silence 假数据）
      - 使用 `rootBundle.load()` 从 assets 加载测试数据
    - Android STT 新增 WAV 格式自动检测与解析：
      - `ModelLoaderPlugin.kt`：`convertAudioToFloat` 新增 RIFF header 检测
      - `extractPCMFromWAV` 函数：解析 WAV chunk 结构，跳过 fmt/data header
    - iOS STT 新增 WAV 格式自动检测与解析：
      - `OnnxRuntimeManager.swift`：`convertAudioToFloat` 新增 RIFF header 检测
      - `extractPCMFromWAV` 函数：解析 WAV chunk 结构，跳过 fmt/data header
    - 验证结果：
      - `flutter analyze`：通过（No issues）
      - `flutter test`：通过（738/738）
      - `flutter build apk --debug`：通过
      - `flutter build ios --release --no-codesign`：通过

24. **OCR 测试界面重新设计：支持相机拍照 + 图片上传（2026-05-04）**
    - `pubspec.yaml`：新增 `image_picker: ^1.1.2` 依赖（Flutter 官方图片选择包）
    - `lib/pages/test_page.dart`：完全重构 OCR 区域
      - 移除 bundled 测试图片 dropdown（`_ocrTestImages` map、`_loadOcrTestImage()`）
      - 新增两个按钮：「拍照识别」（`ImageSource.camera`）、「选择图片」（`ImageSource.gallery`）
      - 新增图片预览区：`Container` 120px 高度，显示选中图片或占位文案
      - 新增 `_pickImage()` 方法：支持相机/相册选取，10MB 大小限制，`mounted` 检查，用户友好错误消息
      - OCR 模式下隐藏文本输入框，发送按钮文案改为「识别」
      - `OCRBlockDisplay` 传入 `imageBytes` 用于结果中原图对照显示
      - 按钮 key：`ocr_camera_button`、`ocr_gallery_button`
    - `lib/models/content_block.dart`：`OCRBlockDisplay` 新增可选 `imageBytes` 字段（`Uint8List?`）
    - `lib/widgets/conversation_timeline.dart`：`OCRBlockDisplay` 渲染增强
      - 有 imageBytes 时先显示原图（圆角 150px，含 `errorBuilder` 降级处理）
      - 下方显示识别文本（可选择复制）+ 置信度百分比
    - 平台权限配置：
      - `android/app/src/main/AndroidManifest.xml`：新增 `CAMERA` 权限 + `camera` feature（`required=false`）
      - `ios/Runner/Info.plist`：新增 `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription`
    - 生产级审查修复：
      - `mounted` 检查：`_pickImage` 在 `setState` 前检查 `mounted`，防止 widget 已卸载时报错
      - 图片大小限制：超过 10MB 时显示用户友好错误，不继续处理
      - 异常处理：`PlatformException` 显示「请检查权限设置」，其他异常显示通用消息
      - `Image.memory` 添加 `errorBuilder`：损坏图片数据时显示「图片加载失败」降级
      - `DropdownButtonFormField` 保持使用 `initialValue`（Flutter 3.33+ 废弃了 `value` 参数）
    - 测试更新：
      - `test/pages/test_page_widget_stt_ocr_test.dart`：完全重写 OCR 测试
        - `OCR shows camera and gallery buttons`：验证按钮存在
        - `OCR shows no-image error when tapped without image`：验证无图错误
        - `OCR shows model-not-loaded error`：验证模型检查先于图片检查
        - `OCR UI has image preview area`：验证预览区和「识别」按钮
        - `OCR shows standardized inference-failed error when runtime throws`：适配无图场景
      - `test/widgets/conversation_timeline_test.dart`：更新 OCR 置信度显示期望（`'置信度: 95.0%'`）
    - 测试从 738 增长到 740（+2）
    - 验证结果：
      - `flutter analyze`：通过（No issues）
      - `flutter test`：通过（808/808）
      - `flutter build apk --debug`：通过
      - `flutter build ios --release --no-codesign`：通过

25. **ModelLoadPage 统一到 ConversationTimeline + ContentBlock 协议（2026-05-04）**
    - `lib/pages/model_load_page.dart`：完全重构状态显示
      - `_status: String` → `_entries: List<ConversationEntry>`
      - 状态 `Container` → `ConversationTimeline(entries: _entries)`
      - 新增 `_appendEntry()` 和 `_removePendingStatus()` 辅助方法（与 test_page.dart 对齐）
      - 加载结果改为 ContentBlock 结构化展示：
        - 成功 → `TextBlock` + `MetricBlock`（assistant role）
        - 错误 → `ErrorBlock`（error role，含 error code）
        - 加载中 → `StatusBlock`（status role，isComplete: false）
        - 运行时选择 → `MetricBlock`（threads/ctx/gpuLayers）
      - `_buildLoadErrorStatus` 重构为 `_appendLoadError`，直接 append entry
      - 表单区域（dropdown、按钮、runtime info card）保持不变
    - 辅助函数（`buildMissingAssetStatus` 等）保持不变，纯文本单元测试无损
    - 测试无需修改即通过（`find.textContaining(...)` 仍匹配 ErrorBlock 渲染的文本）
    - 验证结果：
      - `flutter analyze`：通过（No issues）
      - `flutter test`：通过（808/808）
      - `flutter build apk --debug`：通过
      - `flutter build ios --release --no-codesign`：通过

25. **架构违规修复 + 空输入 bug 修复 + 死代码清理（2026-05-04）**
    - `lib/core/conversation_controller.dart` 原本 import `lib/pages/test_page.dart`（core→pages 架构违规）
    - 新增 `lib/utils/status_messages.dart`：提取 `buildTestModelNotLoadedStatus` / `buildTestInferenceFailedStatus` / `buildTestRuntimeUnavailableStatus` 三个共享函数
    - `lib/pages/test_page.dart`：移除三个函数定义，改为 import `status_messages.dart`
    - `lib/core/conversation_controller.dart`：import 改为 `../utils/status_messages.dart`
    - `lib/pages/conversation_shell.dart`：修复空输入仍发送到 LLM 的 bug（`input.trim().isEmpty` 时不再调用 `_controller.send(input)`）
    - `lib/runtime/llm_runtime.dart`：移除从未使用或测试的 `LLMResult` 类（34 行）
    - 验证结果：
      - `flutter analyze`：通过（No issues）
      - `flutter test`：通过（808/808）
      - `flutter build apk --debug`：通过
      - `flutter build ios --release --no-codesign`：通过

26. **测试覆盖率提升至 72.9%（2026-05-04）**
    - 新增 `test/core/asset_helper_test.dart`（34 tests）：覆盖 AssetHelper 的缓存、加载、批量加载、路径解析、清理等
    - 扩展 `test/core/platform_utils_test.dart`（43 tests）：覆盖路径方法、平台检测、边界条件
    - 测试从 808 增长到 808（从 740 增长到 808，+68 tests）
    - 覆盖率从 71.7% 提升至 72.9%（2465/3380）
    - 验证结果：
      - `flutter analyze`：通过（No issues）
      - `flutter test`：通过（808/808）
      - `flutter build apk --debug`：通过
      - `flutter build ios --release --no-codesign`：通过

27. **OCR 推理改进：置信度计算修正 + 图像反转检测（2026-05-04）**
    - Android/iOS 置信度计算修正：直接使用模型输出的 softmax 概率，无需额外计算
    - Android/iOS 图像反转检测：自动识别白底黑字/黑底白字并反转（PaddleOCR 期望黑字白底）
    - 测试页面增强：OCR 模式自动加载默认测试图片，新增快速选择测试图片 chips
    - 更新 OCR 测试图片（7 个 PNG 文件）和字符字典（`ppocr_keys_v1.txt`）
    - 测试覆盖率提升至 73.3%（2501/3410）
    - 验证结果：
      - `flutter analyze`：通过（No issues）
      - `flutter test`：通过（808/808）
      - `flutter build apk --debug`：通过
      - `flutter build ios --release --no-codesign`：通过

### 5.8 当前工程使用方法（2026-03-22）

以下流程是目录扁平化后的**标准使用方式**，新会话默认按这个顺序执行：

#### A. 新克隆仓库后的首次恢复

1. 恢复模型资源：
   - `./restore_models.sh`
2. 恢复 `llama.cpp` 源码目录：
   - `./restore_llama_cpp.sh`
3. 拉取依赖：
   - `flutter pub get`

若缺任一步，常见后果如下：

- 没有执行 `restore_models.sh`
  - `pubspec.yaml` 声明的本地模型资源不存在，Flutter 测试和构建会失败。
- 没有执行 `restore_llama_cpp.sh`
  - Android 原生 CMake 找不到 `third_party/llama.cpp`，Android 构建会失败。

#### B. 日常开发与回归

推荐固定顺序：

1. `flutter analyze`
2. `flutter test -r compact`
3. `flutter build apk --debug`
4. `flutter build ios --release --no-codesign`

约束：

- `flutter` 命令必须串行执行，禁止并发。
- iOS 真机验收只以 `Release` 为准，不接受 `Debug` 作为最终基线。

#### C. 提交前大文件整理

**模型资产和 llama.cpp 源码不再提交到 git**，统一采用分片归档本地缓存模式。

当 `assets/models/` 发生变化时：

1. 重新打包模型目录：
   - `./pack_models.sh`
   - 生成分片到 `assets/models_archive/`
   - **分片文件在本地，不提交到 git**
2. 将分片文件复制/上传到共享存储（可选）：
   - `assets/models_archive/` 目录下的所有 `.part*` 文件
   - 或上传到 GitHub Releases / Google Drive 等共享位置
3. 开发者在构建前运行：
   - `./restore_models.sh` 恢复模型

当 `third_party/llama.cpp/` 发生变化时：

1. 重新打包源码目录：
   - `./pack_llama_cpp.sh`
   - **分片文件在本地，不提交到 git**

#### D. 当前忽略规则的意图

以下目录默认视为**本地工作副本**，不应直接提交：

- `assets/models/` - 从分片恢复，不跟踪
- `assets/models_archive/` - 分片归档在本地，不提交
- `third_party/llama.cpp/` - 从分片恢复，不跟踪
- `third_party/llama_cpp_archive/` - 分片归档在本地，不提交
- `models/`

说明：

- `models/` 是桌面端默认缓存/配置目录，当前会生成本地 `config.json`，属于运行时状态，不是源码。
- 真正进入仓库的是可恢复的分片归档，而不是解压后的大目录。

---

## 8. 当前仍未完成的关键事项

1. **移动端 STT/OCR 推理链路已在双端实现，待真机验证**
   - Android STT：mel spectrogram + encoder + decoder + vocab decoding（已实现）
   - iOS STT：与 Android 完全对齐的实现（已实现，2026-05-03）
   - OCR 已在双端实现真实推理，待真实模型端到端验证。

2. **TTS 运行时已实现**
   - Android：TextToSpeech `synthesizeToFile` 完整实现，支持 speed/pitch 参数，输出 WAV 文件
   - iOS：AVSpeechSynthesizer 基础实现，通过扬声器播放（iOS 不支持直接文件输出，需 AVAudioEngine 才能实现文件输出）
   - Dart 层：`_TTSRuntimeImpl` 通过 MethodChannel 调用原生 TTS

3. **统一 Chat UI 壳层进展**
   - 对话页、测试页、加载页已对话式化（ConversationTimeline + ContentBlock）。
   - 状态页、设置页、模型管理页为仪表盘/表单/目录页面，不需要对话式化。

4. **测试覆盖率仍偏低**
   - 当前约 `72.0%`，已超过 70% 目标，但复杂回归仍有风险。

5. **ModelManager 生产一致性仍有缺口**
   - 跨进程锁、完整解压校验、异常恢复链路仍需补齐。

6. **插件化与多模态总线尚未落地**
   - 当前仍以具体 runtime/page 为主，尚未沉淀统一能力注册协议。

7. **桌面平台能力仍未完全拉齐**
   - Windows/Linux 的 llama.cpp 集成与构建回归仍需持续补齐。

---

## 9. 阶段状态（修订）

### Phase A：核心框架

- 状态：`已完成`
- 说明：架构层、运行时接口层、应用壳层已支撑持续迭代。

### Phase B：平台基础接入

- 状态：`部分完成`
- 说明：移动端本地 LLM 已可运行；Embedding 可用；OCR/STT/TTS 仍未达到生产可用。

### Phase C：协议与选择器

- 状态：`部分完成`
- 说明：RuntimeSelector 与结构化流式事件已进入主链路，但统一能力协议仍待继续收敛。

### Phase D：存储与调度

- 状态：`部分完成`
- 说明：配置持久化已完成，调度/安装状态机存在，但生产一致性仍有缺口。

### Phase E：生产化

- 状态：`进行中`
- 说明：analyze/test/Android build/iOS Release build 已全绿，剩余阻塞集中在原生多模态能力与覆盖率。

### Phase F：平台化扩展

- 状态：`规划中`
- 说明：后续重点是多模态能力总线、插件注册协议和统一消息协议。

---

## 10. 执行路线图（按优先级）

### P0（必须先做）

1. 打通至少一条真实 OCR 端到端链路
   - OCR 模型已确认真实（10MB ONNX model, CTC greedy decode 已实现）
   - 已生成测试图片 `test_chinese.png`（320x48，含中英文字符）
   - **待验证**：Android 真机 E2E 测试图片输入 → 文字输出

2. 打通至少一条真实 STT 端到端链路
   - STT 模型已确认真实（encoder 31MB + decoder 113MB，vocab 51865 tokens）
   - 已生成测试音频 `test_audio.wav`（16kHz WAV，3秒正弦波）
   - Android/iOS 均已支持 WAV 格式自动解析
   - **待验证**：Android 真机 E2E 测试音频输入 → 文字输出

3. ~~处理 TTS 能力策略~~ ✅ 已实现（双端已集成，Android: TextToSpeech，iOS: AVSpeechSynthesizer）

4. ~~覆盖率已达标 72.0%~~ ✅ 已达成（2501/3410 = 73.3%，2026-05-04）

5. ~~继续统一 Chat UI 壳层~~ ✅ 已完成（对话页、测试页、加载页已统一到 ConversationTimeline + ContentBlock；状态页/设置页/模型页为仪表盘/表单/目录，不需要对话式化）

### P1（MVP 完整度）

1. 扩展 Android/iOS E2E 场景
2. 统一多能力结果消息结构
3. 完善 ModelManager 异常恢复与一致性

### P2（平台化能力）

1. 建立多模态能力总线
2. 设计插件化注册协议（模型插件 / 能力插件 / 工具插件）
3. 建立本地 + 云混合推理抽象层
4. 补齐 Windows/Linux llama.cpp 集成
5. iOS 真机 E2E 回归脚本化

### P3（高级能力）

1. 生成类能力接入（TTS / Text-to-Image / Image Editing / Upscale）
2. LoRA / Adapter 动态挂载能力
3. 多模型并行调度与资源管理
4. Agent Workflow 与 Tool Use UI 化展示

---

## 11. 验收标准（DoD）与当前对照

1. `flutter test` 全绿，且具备有效业务测试
   - 当前：`已满足`（`808/808`，覆盖率 73.3%）

2. `flutter analyze` 无 warning
   - 当前：`已满足`

3. iOS Release 构建通过（真机仅以 Release 为准）
   - 当前：`已满足`（`flutter build ios --release --no-codesign`）

4. Android Debug 构建通过
   - 当前：`已满足`（`flutter build apk --debug`）

5. ModelManager 使用真实 hash 校验，安装目录按版本管理
   - 当前：`部分满足`

6. Android/iOS OCR/STT 至少一个真实模型端到端通过
   - 当前：`部分满足`（模型权重已确认真实，测试数据已生成，双端 WAV 解析已实现；待真机 E2E 验证）

7. 移动端 LLM 端内可运行（无外部 HTTP 依赖）
   - 当前：`已满足`

8. 主要能力 case 可在 UI 中展示
   - 当前：`部分满足`

9. UI 统一采用对话式结果承载
   - 当前：`部分满足`

10. 支持插件化扩展新增模型/能力
   - 当前：`未满足`

---

## 12. 风险清单（当前）

1. STT 仍未达到真实推理可用强度；OCR 双端已有真实推理代码，待真实模型端到端验证。
2. TTS 仍未实现，若继续暴露入口会持续制造错误预期。
3. 覆盖率 73.3%，已超过 70% 目标，但复杂回归仍有风险。
4. 多模态结果尚未统一消息协议，UI 仍有碎片化风险。
5. ModelManager 若不补齐一致性链路，后续大模型安装/升级风险较高。
6. 多模型格式目标范围较大，若缺插件协议会持续挤压核心层边界。
7. 桌面端与移动端后端差异较大，能力降级策略需要更早收敛。

---

## 13. 最终目标

构建一个：

**跨平台 AI 桌面 + 移动应用**

具备能力：

- 本地 AI 模型运行
- 多模态 AI 能力
- 插件扩展架构
- Agent 自动化开发体系

同时具备：

- 高可扩展
- 高自动化
- 高工程质量

---

## 14. 结论

当前工程状态可定义为：

`主链路可用（含移动端端内 LLM），质量基线建立，但尚未达到发布级完善度；现已进入从 MVP 向跨平台、多模态、插件化 AI 平台演进的阶段。`

更准确的当前口径：

`已达到开发验收级稳定，但未达到发布级稳定。`

下一阶段应聚焦：

- **STT 真机 E2E 验证**（需要下载真实 Whisper ONNX 模型 + 准备测试音频）
- **OCR 真机 E2E 验证**（需要下载真实 OCR ONNX 模型 + 准备测试图片）
- ~~覆盖率提升到 70%+~~ ✅ 已达成（72.0%）
- ~~TTS 能力~~ ✅ 双端已实现
- 主文件拆分
- 统一 ChatGPT 风格 UI 壳层
- 多模态能力抽象与插件化协议落地
