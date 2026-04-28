#!/usr/bin/env bash
set -euo pipefail

# Download a CRNN-based ONNX OCR recognition model.
# Targets PaddleOCR PP-OCRv4 mobile rec model (multilingual).
#
# Usage:
#   ./scripts/download_ocr_model.sh
#
# After running, the model will be at:
#   assets/models/ocr/model.onnx
#   assets/models/ocr/ppocr_keys_v1.txt  (character dictionary)
#   assets/models/ocr/model_config.json  (updated)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OCR_DIR="$PROJECT_ROOT/assets/models/ocr"

# PaddleOCR PP-OCRv4 mobile recognition model (ONNX export)
# Source: https://paddleocr.bj.bcebos.com/PP-OCRv4/chinese/ch_PP-OCRv4_rec_infer.tar
# Converted to ONNX via paddle2onnx
MODEL_URL="https://github.com/RapidAI/RapidOCR/raw/main/python/tests/test_files/ch_PP-OCRv4_rec_infer/inference.onnx"
DICT_URL="https://raw.githubusercontent.com/PaddlePaddle/PaddleOCR/release/2.7/ppocr/utils/ppocr_keys_v1.txt"

# Fallback: use a smaller CRNN model if the above is unavailable
FALLBACK_MODEL_URL="https://github.com/RapidAI/RapidOCR/raw/main/python/tests/test_files/ch_PP-OCRv4_rec_infer/inference.onnx"

mkdir -p "$OCR_DIR"

echo "=== OCR Model Downloader ==="
echo "Target directory: $OCR_DIR"
echo ""

# Download model
MODEL_PATH="$OCR_DIR/model.onnx"
if [ -f "$MODEL_PATH" ] && [ "$(wc -c < "$MODEL_PATH")" -gt 1000000 ]; then
    echo "[OK] Model already exists ($(du -h "$MODEL_PATH" | cut -f1)): $MODEL_PATH"
else
    echo "[..] Downloading OCR model..."
    if curl -fsSL --connect-timeout 30 --max-time 300 -o "$MODEL_PATH" "$MODEL_URL"; then
        echo "[OK] Downloaded: $MODEL_PATH ($(du -h "$MODEL_PATH" | cut -f1))"
    else
        echo "[!!] Primary download failed, trying fallback..."
        if curl -fsSL --connect-timeout 30 --max-time 300 -o "$MODEL_PATH" "$FALLBACK_MODEL_URL"; then
            echo "[OK] Downloaded (fallback): $MODEL_PATH ($(du -h "$MODEL_PATH" | cut -f1))"
        else
            echo "[FAIL] All downloads failed. Please download manually:"
            echo "  1. Get ONNX model from: https://github.com/RapidAI/RapidOCR"
            echo "  2. Place it at: $MODEL_PATH"
            exit 1
        fi
    fi
fi

# Download character dictionary
DICT_PATH="$OCR_DIR/ppocr_keys_v1.txt"
if [ -f "$DICT_PATH" ] && [ "$(wc -l < "$DICT_PATH")" -gt 100 ]; then
    echo "[OK] Dictionary already exists ($(wc -l < "$DICT_PATH") lines): $DICT_PATH"
else
    echo "[..] Downloading character dictionary..."
    if curl -fsSL --connect-timeout 30 --max-time 60 -o "$DICT_PATH" "$DICT_URL"; then
        echo "[OK] Downloaded: $DICT_PATH ($(wc -l < "$DICT_PATH") lines)"
    else
        echo "[WARN] Dictionary download failed. CTC decode will use index-only mode."
    fi
fi

# Update model_config.json
cat > "$OCR_DIR/model_config.json" << 'JSONEOF'
{
  "model_id": "ppocr-v4-mobile",
  "family": "ocr",
  "format": "onnx",
  "file": "model.onnx",
  "task": "ocr",
  "architecture": "CRNN",
  "input": {
    "name": "x",
    "shape": [1, 3, 48, 320],
    "dtype": "float32",
    "normalize": {
      "mean": [0.5, 0.5, 0.5],
      "std": [0.5, 0.5, 0.5]
    }
  },
  "output": {
    "name": "softmax_0.tmp_0",
    "shape": [1, "seq_len", "num_classes"],
    "dtype": "float32"
  },
  "character_dict": "ppocr_keys_v1.txt",
  "rec_image_shape": [3, 48, 320],
  "rec_batch_num": 6,
  "max_text_length": 25
}
JSONEOF
echo "[OK] Updated model_config.json"

echo ""
echo "=== Done ==="
echo "Model: $MODEL_PATH"
echo "Dict:  $DICT_PATH"
echo "Config: $OCR_DIR/model_config.json"
echo ""
echo "Next: rebuild the APK to include the new assets."
