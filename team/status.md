# ModelLoader 团队状态文档

更新时间: 2026-03-22

## 团队成员

| 角色 | Agent ID | 状态 |
|------|----------|------|
| Team Leader | team-lead | ✅ 协调完成 |
| AI Engineer | ai-engineer | ✅ 就绪 |
| Flutter Expert | flutter-expert | ✅ 就绪 |
| Research Expert | research-expert | ✅ 调研完成 |
| QA Engineer | qa-engineer | ✅ 测试完成 |

## 当前项目状态

- **测试**: 453/453 全部通过 ✅
- **Analyze**: No issues found ✅
- **覆盖率**: **60.46%** ⬆️
- **构建**: iOS Release / Android Debug 均通过 ✅

---

## 进度里程碑

### ✅ 已完成

| 日期 | 任务 | 结果 |
|------|------|------|
| 2026-03-22 | llama.cpp 归档分片 | `third_party/llama.cpp/` 已切换为分片归档提交流程，新增 `pack_llama_cpp.sh` / `restore_llama_cpp.sh` |
| 2026-03-22 | models 归档分片 | `assets/models/` 已压缩为 `assets/models_archive/assets_models.tar.gz.partNNN`，按 `49MB` 分片并附带 `sha256` 校验；新增 `pack_models.sh` / `restore_models.sh` |
| 2026-03-22 | GitHub 提交前整理 | 抽取共享 LLM 模型目录，收敛加载页/设置页重复配置；README 改为真实项目说明并补充大文件风险提示 |
| 2026-03-22 | App 端链路测试增强 | 新增 AppShell 级“加载 -> 对话”测试，覆盖 4 个内置 LLM 选项与 macOS/desktop bootstrap |
| 2026-03-22 | 覆盖率复验 | 59.75% → 60.46% |
| 2026-03-22 | 目录调整后复验 | 根目录扁平化后 `flutter analyze` / `flutter test` / Android / iOS 构建仍通过 |
| 2026-03-22 | 覆盖率复验 | 59.1% → 59.75% |
| 2026-03-21 | 真机构建安装 | iOS `release` / Android `debug` 装机成功 |
| 2026-03-21 | 基线修复 | `flutter analyze` / `flutter test` 全绿 |
| 2026-03-21 | 覆盖率提升 | 53.9% → 59.1% |
| 2026-03-14 | 测试修复 | 1 error → 0 errors |
| 2026-03-14 | 测试数量 | 104 → 131 (+27) |
| 2026-03-14 | 覆盖率提升 | 28% → 53.9% |
| 2026-03-14 | 设置持久化 | 已实现 |
| 2026-03-14 | AI 模型调研 | 完整报告 ✅ |

### ⏳ 进行中

| 任务 | 当前进度 | 目标 | 预计时间 |
|------|----------|------|----------|
| 覆盖率提升 | 60.46% | 80% | ~2-4小时 |

---

## 覆盖率目标

```
当前: ██████████████████░░░░░░ 60.46%
目标: ████████████████████████░░ 80%

剩余: ░░░░░░░░░░░░░░░░░░░░░ 19.54%
```

### 时间估算

| 阶段 | 预计时间 |
|------|----------|
| 60% | 已达到 |
| 70% | ~1-2 小时 |
| 80% | ~2-4 小时 |

---

## P0 任务完成

| 任务 | 状态 |
|------|------|
| 设置持久化 | ✅ 已实现 |
| 测试覆盖率提升 | 🔄 60.46% → 80% |
| LLM 流式事件结构化 | ✅ 已实现 |
| AI 模型技术调研 | ✅ 已完成 |

---

## 调研成果

- `team/research/model-options.md` - 模型方案对比
- `team/research/recommendations.md` - 推荐方案

### 推荐方案

| 能力 | 推荐 | 模型大小 |
|------|------|----------|
| LLM | llama.cpp + Qwen3.5-0.8B | ~1.6GB (Q4) |
| Embedding | bge-small-en-v1.5 | ~130MB |
| ONNX | Runtime Mobile 1.16+ | - |

## 协作规则

1. 所有任务通过文档同步
2. 任务分配 → 执行 → 验收 全程文档化
3. 每日同步团队状态
