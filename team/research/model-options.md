# AI 模型技术调研报告

**调研时间**: 2026-03-14
**调研人**: Research Expert

---

## 1. 移动端本地 LLM 方案

### 1.1 llama.cpp

**概述**: 最成熟的本地 LLM 推理框架

**移动端支持**:
- **iOS**: 官方支持 Apple Silicon (ARM NEON, Accelerate, Metal)
- **Android**: 官方示例在 `examples/llama.android`
- React Native 绑定: `mybigday/llama.rn`

**性能特性**:
- 量化支持: 1.5-bit 到 8-bit 整数量化
- GPU 加速: CUDA (NVIDIA), HIP (AMD), Vulkan, Metal (Apple)
- 混合推理: 支持 CPU+GPU 混合处理大于 VRAM 的模型

**项目地址**: https://github.com/ggerganov/llama.cpp

---

### 1.2 Qwen 模型族

**概述**: 阿里巴巴云开发的大语言模型家族

**移动端友好模型**:

| 模型 | 参数 | 下载量 | 适用场景 |
|------|------|--------|----------|
| Qwen3.5-0.8B | 0.9B | 797k | 移动端首选 |
| Qwen3.5-2B | 2B | 528k | 移动端/边缘 |
| Qwen3.5-35B-A3B-GPTQ-Int4 | 36B | 210k | 性能要求高 |

**GGUF 格式支持**: ✅ 支持
- `Qwen/Qwen3-Coder-Next-GGUF` (80B, 48.9k downloads)

**量化模型 (Int4)**:
- Qwen3.5-35B-A3B-GPTQ-Int4
- Qwen3.5-27B-GPTQ-Int4

**项目地址**: https://huggingface.co/Qwen

---

### 1.3 其他移动端方案

| 方案 | 特点 | 状态 |
|------|------|------|
| gemma.cpp | Google Gemma 模型官方推理 | 发展中 |
| mllm | 多语言 LLM 移动端推理 | 实验性 |
| MLX (Apple) | Apple 芯片专用 | 仅 macOS/iOS |

---

## 2. ONNX Runtime 移动端

### 2.1 概述

ONNX Runtime 提供跨平台推理能力，支持 Android 和 iOS。

### 2.2 移动端支持

- **Android**: ONNX Runtime Mobile
- **iOS**: ONNX Runtime Mobile
- **支持平台**: Linux, Windows, Mac, iOS, Android, Web

### 2.3 支持的模型格式

- PyTorch 导出模型
- TensorFlow 模型
- Keras 模型
- 主流 Hugging Face 模型 (如 Llama-2-7b)

### 2.4 版本信息

最新稳定版本请参考: https://onnxruntime.ai/

---

## 3. Embedding 模型

### 3.1 BAAI/bge-small-en

**基本信息**:
- 参数: 33.4M
- 维度: 384
- 序列长度: 512
- 许可证: MIT (可商用)

**MTEB 性能**:

| 任务类型 | 得分 |
|----------|------|
| 平均 (56 数据集) | 62.11 |
| Retrieval (15) | 51.82 |
| STS (10) | 80.72 |
| Classification (12) | 74.37 |

**推荐版本**: BAAI/bge-small-en-v1.5 (更合理的相似度分布)

**下载量**: 278,265/月

**项目地址**: https://huggingface.co/BAAI/bge-small-en

---

### 3.2 其他高效 Embedding 模型

| 模型 | 参数 | 维度 | 特点 |
|------|------|------|------|
| BAAI/bge-base-en | 86M | 768 | 更高精度 |
| BAAI/bge-large-en | 335M | 1024 | 最高精度 |
| intfloat/e5-small-v2 | 33M | 384 | 快速推理 |
| sentence-transformers/all-MiniLM-L6-v2 | 23M | 384 | 轻量级 |

---

## 4. 量化级别参考

### GGUF 量化格式

| 级别 | 位宽 | 7B 模型大小 | 质量 |
|------|------|-------------|------|
| Q4_0 | 4-bit | ~3.5GB | 良好平衡 |
| Q4_1 | 4-bit | ~3.7GB | 略好质量 |
| Q5_0 | 5-bit | ~4.3GB | 更好质量 |
| Q5_1 | 5-bit | ~4.5GB | 高质量 |
| Q8_0 | 8-bit | ~7GB | 接近 fp16 |

---

## 5. 移动端模型推荐

### 5.1 轻量级 LLM (首选)

1. **Qwen3.5-0.8B**
   - 大小: ~1.6GB (Q4 量化)
   - 内存需求: 2-3GB
   - 适用: 移动端入门

2. **Qwen3.5-2B**
   - 大小: ~2.5GB (Q4 量化)
   - 内存需求: 4-5GB
   - 适用: 主流移动设备

### 5.2 Embedding 模型

1. **BAAI/bge-small-en-v1.5** (推荐)
   - 大小: ~130MB
   - 维度: 384
   - 性能: MTEB 62.11

2. **intfloat/e5-small-v2**
   - 大小: ~130MB
   - 维度: 384
   - 快速推理

---

## 6. 结论与建议

### 6.1 LLM 推理

**推荐方案**: llama.cpp + Qwen3.5 系列

理由:
- llama.cpp 移动端支持最成熟
- Qwen 提供官方 GGUF 量化模型
- 0.8B-2B 适合移动端内存

### 6.2 Embedding

**推荐方案**: BAAI/bge-small-en-v1.5

理由:
- 33M 参数，体积小
- 384 维度，兼容性好
- MIT 许可证，可商用

---

*本报告基于 2026-03-14 的网络调研*
