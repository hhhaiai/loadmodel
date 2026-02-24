# ModelLoader SDK 需求评审与修订版 (v0.4)

## 一、评审结论

整体方向合理，且 v0.2 已经具备可交付雏形。  
v0.4 在 v0.3 基础上补齐三项高优先级细节：流式事件语义、可复现降级策略、安装状态机与进度事件。

## 二、范围与目标（保持不变）

### 2.1 MVP 范围

- 桌面端优先：LLM（llama.cpp）
- 移动端优先：OCR/STT/Embedding（ONNX Runtime）
- TTS、Classification 放入后续阶段

### 2.2 当前代码状态对齐

- iOS 已接入 `onnxruntime-c`，且有 OCR/STT/Embedding 原型实现
- Android 已接入 `onnxruntime-android`，当前推理仍以占位逻辑为主
- 桌面端 LLM 为 llama.cpp 进程封装原型，协议与稳定性需继续完善

## 三、模型清单协议（执行契约）

### 3.1 顶层字段（必填）

- `manifestSchemaVersion`：清单协议版本，例 `1.0.0`
- `manifestVersion`：清单内容版本，例 `2026.02.24`
- `generatedAt`：UTC 时间戳
- `models`：模型列表

### 3.2 模型字段（必填/建议）

- 必填：
  - `id`
  - `type`
  - `version`
  - `backendHints`
  - `requiredArtifacts`
  - `platforms`
- 建议：
  - `optionalArtifacts`
  - `minSdkVersion`
  - `minBackendVersion`
  - `quantization`
  - `contextLength`
  - `ropeScaling`
  - `ropeTheta`
  - `defaultGenerationConfig`
  - `chatTemplate`
  - `specialTokens`

### 3.3 Artifact 字段（必填）

- `name`
- `role`（`model`/`tokenizer`/`config`/`vocab`/`adapter`）
- `format`
- `path`
- `size`
- `sha256`

### 3.4 清单示例

```json
{
  "manifestSchemaVersion": "1.0.0",
  "manifestVersion": "2026.02.24",
  "generatedAt": "2026-02-24T08:00:00Z",
  "models": [
    {
      "id": "llama3.1-8b-q4km",
      "type": "llm",
      "version": "1.0.0",
      "backendHints": ["llama.cpp"],
      "minSdkVersion": {"android": 24, "ios": "15.1"},
      "minBackendVersion": {"llama.cpp": "0.0.0", "onnxruntime": "1.16.3"},
      "quantization": "Q4_K_M",
      "contextLength": 8192,
      "ropeScaling": "linear",
      "ropeTheta": 10000,
      "defaultGenerationConfig": {
        "temperature": 0.7,
        "topP": 0.9,
        "topK": 40,
        "repeatPenalty": 1.1,
        "maxTokens": 1024
      },
      "chatTemplate": "chatml",
      "specialTokens": {"bos": "<s>", "eos": "</s>"},
      "requiredArtifacts": [
        {
          "name": "model",
          "role": "model",
          "format": "gguf",
          "path": "llama3.1-8b-q4km.gguf",
          "size": 4870000000,
          "sha256": "..."
        }
      ],
      "optionalArtifacts": [
        {
          "name": "tokenizer",
          "role": "tokenizer",
          "format": "spm",
          "path": "tokenizer.model",
          "size": 512000,
          "sha256": "..."
        }
      ],
      "platforms": ["macos", "windows", "linux"]
    }
  ]
}
```

## 四、RuntimeSelector 决策规则（固定）

按以下顺序执行，不允许平台各自定义顺序：

1. 过滤 `platforms`、`minSdkVersion`、`minBackendVersion`
2. 若命中 `backendHints` 且后端可用，优先该后端
3. 同时可用时优先硬件加速（CoreML/NNAPI/GPU），不稳定则回退 CPU
4. 若资源不足（内存/存储/线程预算），按顺序降级：
   - 更小 quantization
   - 更短 contextLength
   - 更低 threads / gpuLayers
5. 仍不可运行则返回 `RUNTIME_NOT_AVAILABLE`，并附诊断详情

### 4.1 降级候选生成规则（可复现）

- `quantization` 降级候选必须来自清单显式定义（例如 `variants` 或显式候选列表），禁止运行时字符串猜测
- `contextLength` 仅允许固定阶梯降级：`8192 -> 4096 -> 2048`
- `threads` 取值范围：`[1, cpuCores]`，默认 `max(1, cpuCores - 1)`
- `gpuLayers` 取值范围：`[0, model.maxGpuLayers]`，资源不足时优先降到 `0`
- 当某一步没有候选时，直接进入下一降级维度，不允许重复尝试同一候选

### 4.2 诊断输出结构（SelectionReport）

```json
{
  "requestId": "sel_123",
  "candidates": [
    {
      "backend": "llama.cpp",
      "provider": "gpu",
      "accepted": false,
      "reasons": ["INSUFFICIENT_MEMORY"]
    },
    {
      "backend": "llama.cpp",
      "provider": "cpu",
      "accepted": true,
      "reasons": []
    }
  ],
  "downgradeSteps": [
    {"dimension": "quantization", "from": "Q5_K_M", "to": "Q4_K_M"},
    {"dimension": "contextLength", "from": 8192, "to": 4096}
  ],
  "finalDecision": {
    "backend": "llama.cpp",
    "provider": "cpu",
    "quantization": "Q4_K_M",
    "contextLength": 4096,
    "threads": 6,
    "gpuLayers": 0
  }
}
```

## 五、LLM 协议（统一输出）

### 5.1 请求配置（基于现有命名）

在现有 `GenerationConfig` / `LLMConfig` 基础上统一支持：

- `seed`
- `topK`
- `repeatPenalty`
- `stopStrings`
- `batchSize`
- `threads`

### 5.2 流式事件 Schema（所有后端统一）

```json
{
  "eventType": "delta",
  "requestId": "req_123",
  "sequence": 1,
  "deltaText": "增量文本",
  "tokenIds": [123, 456],
  "stats": {
    "promptTokens": 128,
    "completionTokens": 12,
    "timeToFirstTokenMs": 320,
    "msPerToken": 22.4
  },
  "finishReason": "eos",
  "error": {
    "code": "",
    "message": "",
    "retriable": false
  }
}
```

约束：

- `eventType` 仅允许：`delta`/`metrics`/`finish`/`error`
- `delta` 事件必须包含 `deltaText`（可为空串）
- `finish` 事件必须包含 `finishReason` 与最终 `stats`
- `error` 事件必须包含 `error`，且 `finishReason` 固定为 `error`
- `finishReason` 仅允许：`eos`/`length`/`stop`/`cancel`/`error`
- `requestId` 在同一请求生命周期内必须稳定，`sequence` 必须严格递增

### 5.3 stopStrings 匹配规则（固定）

- 必须支持跨 chunk 匹配（不能只在单个 chunk 内判断）
- 默认不输出 stop 片段；若输出则必须由明确配置开关控制
- 命中 stop 后，最后一个事件必须为 `finish`，且 `finishReason=stop`

### 5.4 非流式输出 Schema

```json
{
  "text": "完整输出",
  "finishReason": "stop",
  "stats": {
    "promptTokens": 128,
    "completionTokens": 256,
    "timeToFirstTokenMs": 300,
    "msPerToken": 18.3
  }
}
```

## 六、ModelManager 行为规范（生产必需）

### 6.1 下载与校验

- 先下载到临时文件：`*.tmp`
- 下载完成后校验 `sha256`
- 校验通过后原子 `rename`
- 失败自动清理临时文件

### 6.2 并发锁（单飞）

- 同一 `(modelId, version)` 并发下载必须单飞
- 采用进程内互斥 + 文件锁（跨进程）双层保护
- 后到请求等待或复用已在进行中的任务

### 6.3 压缩包处理（若 artifacts 为 zip/tar）

- 解压前校验压缩包 hash
- 解压后逐 artifact 校验 hash
- 解压到临时目录，全部成功后原子切换目录

### 6.4 版本与清理

- 路径规范：`{cacheDir}/{modelId}/{version}/...`
- 不覆盖历史版本，支持激活版本切换与回滚
- 空间阈值触发 LRU，保留最近使用版本

### 6.5 安装状态机与进度事件（统一）

状态机：

- `idle -> downloading -> verifying -> extracting -> ready`
- 失败进入 `failed`
- 取消进入 `cancelled`

进度事件 Schema：

```json
{
  "modelId": "llama3.1-8b-q4km",
  "version": "1.0.0",
  "phase": "downloading",
  "receivedBytes": 1048576,
  "totalBytes": 4870000000,
  "progress": 0.0002,
  "requestId": "install_123",
  "error": null
}
```

约束：

- 每个 phase 切换必须发出至少一个事件
- `failed/cancelled/ready` 必须作为终态事件输出
- `failed` 事件中的 `error` 结构复用第 8 章定义

## 七、TaskScheduler MVP 契约（先定接口）

### 7.1 统一提交接口

- `submit(task, priority, timeout, cancellable)`

### 7.2 必须支持能力

- 取消
- 超时
- 最大并发
- 按 runtime 分队列（示例：LLM 单通道，OCR 并发 2）

### 7.3 资源维度

- 任务标注：`cpuBound` / `gpuBound` / `ioBound`
- 下载任务与推理任务分离队列，避免 IO 阻塞推理

## 八、错误码与诊断模型

### 8.1 标准错误码

- `MODEL_NOT_FOUND`
- `MODEL_VERIFY_FAILED`
- `RUNTIME_NOT_AVAILABLE`
- `UNSUPPORTED_PLATFORM`
- `INSUFFICIENT_MEMORY`
- `TASK_TIMEOUT`
- `TASK_CANCELLED`

### 8.2 结构化错误信息（必填规范）

```json
{
  "code": "MODEL_VERIFY_FAILED",
  "message": "artifact sha256 mismatch",
  "retriable": true,
  "details": {
    "backend": "onnxruntime",
    "artifact": "encoder.onnx",
    "expectedSha256": "...",
    "actualSha256": "...",
    "requiredMemoryMB": 4096,
    "availableMemoryMB": 2730
  },
  "suggestion": "re-download model or switch to lower quantization"
}
```

## 九、开发计划（v0.4）

### Phase A: 核心框架（已完成）

- [x] SDK 基础结构
- [x] ModelManager / ConfigManager 基础能力
- [x] Runtime 接口定义

### Phase B: 平台基础接入（部分完成）

- [x] iOS ONNX 依赖接入
- [x] Android ONNX 依赖接入
- [~] iOS OCR/STT/Embedding 原型推理
- [ ] Android OCR/STT 真实推理落地

### Phase C: 协议与选择器（P0）

- [ ] 模型清单契约字段全量落地（本文件第 3 章）
- [ ] RuntimeSelector 决策表实现 + 诊断输出（第 4 章）
- [ ] LLM 流式事件 Schema 全后端对齐（含 `eventType` 与 stop 规则，第 5 章）

### Phase D: 存储与调度（P0）

- [ ] ModelManager 单飞锁 + 原子下载 + 逐 artifact 校验（含状态机与进度事件，第 6 章）
- [ ] TaskScheduler MVP（取消/超时/并发/分队列）
- [ ] 统一错误结构落地

### Phase E: 生产化（P1）

- [ ] 端到端测试与稳定性压测
- [ ] 安全增强（签名链路、可选 pinning）
- [ ] TTS 与 Classification 补全

## 十、当前状态总结（基于仓库）

- 架构方向正确，MVP 路线已收敛
- 依赖接入已完成（iOS/Android ONNX）
- 平台实现不均衡：iOS 原型较前，Android/桌面仍需工程化
- v0.4 已补齐流式语义、降级可复现规则、安装状态机三项关键防分叉约束
