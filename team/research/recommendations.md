# 推荐方案报告

**调研时间**: 2026-03-14
**调研人**: Research Expert

---

## 1. 执行摘要

基于 ModelLoader 项目需求，推荐以下方案:

| 能力 | 推荐方案 | 理由 |
|------|----------|------|
| LLM 推理 | llama.cpp + Qwen3.5-0.8B | 移动端成熟，模型易获取 |
| Embedding | BAAI/bge-small-en-v1.5 | 轻量，高效，MTEB 62 分 |
| ONNX | ONNX Runtime Mobile | 跨平台统一推理 |

---

## 2. 详细推荐

### 2.1 LLM 推理引擎

**首选**: llama.cpp

| 指标 | 评估 |
|------|------|
| iOS 支持 | ⭐⭐⭐⭐⭐ 官方 Metal 支持 |
| Android 支持 | ⭐⭐⭐⭐ 官方示例 |
| 量化支持 | ⭐⭐⭐⭐⭐ 1.5-8 bit |
| 社区活跃 | ⭐⭐⭐⭐⭐ 活跃 |

**备选**:
- MLX (仅 Apple 生态)
- ONNX Runtime (需转换模型)

---

### 2.2 LLM 模型

**移动端首选**: Qwen3.5-0.8B

| 指标 | 数值 |
|------|------|
| 参数 | 0.9B |
| 量化后大小 | ~1.6GB (Q4) |
| 内存需求 | 2-3GB |
| 月下载 | 797k |
| GGUF 支持 | ✅ |

**进阶选择**: Qwen3.5-2B
- 参数: 2B
- 量化后: ~2.5GB
- 内存需求: 4-5GB
- 更高对话质量

---

### 2.3 Embedding 模型

**首选**: BAAI/bge-small-en-v1.5

| 指标 | 数值 |
|------|------|
| 参数 | 33.4M |
| 维度 | 384 |
| 模型大小 | ~130MB |
| MTEB 平均 | 62.11 |
| 许可证 | MIT |

**备选对比**:

| 模型 | 参数 | 维度 | MTEB | 大小 |
|------|------|------|------|------|
| bge-small-en-v1.5 | 33M | 384 | 62.11 | ~130MB |
| all-MiniLM-L6-v2 | 23M | 384 | 56.23 | ~90MB |
| e5-small-v2 | 33M | 384 | 55.83 | ~130MB |

**结论**: bge-small-en-v1.5 在精度和体积间取得最佳平衡。

---

### 2.4 ONNX Runtime

**移动端策略**:

| 平台 | 推荐配置 |
|------|----------|
| Android | ONNX Runtime Mobile 1.16+ |
| iOS | ONNX Runtime Mobile 1.16+ |
| 桌面 | ONNX Runtime (完整版) |

**支持的操作**:
- BERT/Transformers 系列
- 图像分类
- 目标检测
- 自定义算子 (通过扩展)

---

## 3. ModelLoader 集成建议

### 3.1 短期 (MVP)

```
assets/models/
├── qwen3.5-0.8b-q4/      # LLM
│   └── qwen3.5-0.8b-q4.gguf
├── bge-small-en-v1.5/   # Embedding
│   └── bge-small-en-v1.5.onnx
└── tinyllama/            # 备用
```

### 3.2 中期 (扩展)

- 添加 Qwen3.5-2B (高性能场景)
- 添加 OCR 模型 (whisper-base)
- 添加 STT 模型

### 3.3 长期 (完善)

- LoRA adapter 支持
- 多模型并行
- 云端混合推理

---

## 4. 风险与规避

| 风险 | 规避措施 |
|------|----------|
| 模型版权 | 使用 MIT/Apache 2.0 许可证模型 |
| 内存不足 | 从 0.8B 开始，逐步升级 |
| 性能问题 | 预量化模型 + GGUF 格式 |
| iOS 限制 | 使用 Metal 加速 + 动态库 |

---

## 5. 参考资源

- llama.cpp: https://github.com/ggerganov/llama.cpp
- Qwen Models: https://huggingface.co/Qwen
- BGE Embedding: https://huggingface.co/BAAI/bge-small-en
- ONNX Runtime: https://onnxruntime.ai/

---

*本报告基于 2026-03-14 的网络调研*
