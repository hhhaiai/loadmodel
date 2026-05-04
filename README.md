# ModelLoader

一个基于 Flutter 的本地 AI 模型加载与对话实验项目，目标是把 LLM、Embedding、OCR、STT、TTS 这几类能力统一到同一个 app 壳层里，在移动端和桌面端提供一致的加载、测试和对话体验。

当前仓库根目录为 `/Users/sanbo/Desktop/loadmodel`，不再使用旧的 `model_loader/` 子目录结构。

## 当前状态

- `flutter analyze` 通过
- `flutter test` 通过，当前基线 `453/453`
- `flutter build apk --debug` 通过
- `flutter build ios --release --no-codesign` 通过
- app 端已经补上 `AppShell` 级主链路测试，覆盖“加载 LLM -> 切到对话页 -> 发送消息 -> 收到回复”

更完整的执行基线、真机验证记录和开发黑名单见 [CLAUDE.md](./CLAUDE.md)。

## 目录说明

- `lib/app/`: 启动引导、MaterialApp 和导航壳层
- `lib/pages/`: 加载页、对话页、测试页、状态页、设置页等 UI 页面
- `lib/runtime/`: LLM、ONNX、stub 等运行时封装
- `lib/core/`: 配置、任务调度、模型管理、对话控制等核心逻辑
- `lib/models/`: 模型定义、推理事件、共享配置目录
- `test/`: 单元测试和 Widget 测试
- `integration_test/`: 集成测试
- `android/`, `ios/`, `macos/`: 原生桥接与平台工程

## 快速开始

```bash
git clone https://github.com/hhhaiai/loadmodel.git
cd loadmodel
make prepare        # 一键恢复模型 + llama.cpp + 安装依赖
make test           # 运行测试
make build-apk      # 构建 Android APK
make build-ios      # 构建 iOS (无签名)
```

运行 `make` 查看所有可用命令。

### 手动方式（不用 Makefile）

```bash
./restore_models.sh
./restore_llama_cpp.sh
flutter pub get
flutter analyze
flutter test -r compact
flutter build apk --debug
flutter build ios --release --no-codesign
```

推荐串行执行 `flutter` 命令，不要并发跑 `analyze`、`test`、`build`。

## 模型归档

- 仓库提交的是 `assets/models_archive/` 下的分片包，不直接提交解压后的 `assets/models/`
- 当前分片规则是 `49MB` 一片，归档名为 `assets_models.tar.gz`
- 恢复模型目录：`./restore_models.sh`
- 重新打包模型目录：`./pack_models.sh`
- `assets/models/` 已加入 `.gitignore`，本地解压后不会被误提交

## llama.cpp 归档

- 仓库提交的是 `third_party/llama_cpp_archive/` 下的分片包，不直接提交解压后的 `third_party/llama.cpp/`
- 当前分片规则也是 `49MB` 一片，归档名为 `third_party_llama_cpp.tar.gz`
- 恢复源码目录：`./restore_llama_cpp.sh`
- 重新打包源码目录：`./pack_llama_cpp.sh`
- `third_party/llama.cpp/` 已加入 `.gitignore`，本地解压后不会被误提交

如果你是新克隆仓库，先执行 `./restore_models.sh` 和 `./restore_llama_cpp.sh`，再跑 Flutter 的测试和构建。也可以直接运行 `./prepare.sh` 或 `make prepare` 一键完成所有步骤。

恢复脚本支持增量检查：如果目标目录已存在，会自动跳过解压。使用 `--force` 参数强制重新解压。

## 已验证的能力

- 移动端 LLM 已切换到 MethodChannel + 原生 bridge，不再依赖本地 HTTP 服务
- 桌面端 LLM 默认走 `llama.cpp`
- 设置页支持保存模型、温度、上下文长度和系统提示词
- 对话页支持流式回复、错误展示和清空对话
- app 端测试已覆盖 4 个内置 LLM 选项的加载与对话主流程

## 仍未完成

- Android / iOS 的 OCR、STT 还没有真正完成生产级推理链路
- TTS 仍未实现
- 覆盖率还没到发布级
- Windows / Linux 的桌面能力还需要继续补齐

## 提交到 GitHub 前请注意

- `assets/models/` 已改成压缩包分片提交，当前为 `58` 个分片文件加一个 `sha256` 校验文件
- `third_party/llama.cpp/` 也应走同样的分片归档提交流程，不要直接提交解压后的源码目录
- 如果要推到新的 GitHub 仓库，建议先明确大文件策略：`git-lfs`、外部下载脚本，或者恢复为子模块/外部依赖

否则代码本身没问题，远端推送也可能直接失败。
