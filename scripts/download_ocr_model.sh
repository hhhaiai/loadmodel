#!/usr/bin/env bash
set -euo pipefail

# Download and convert PaddleOCR PP-OCRv4 ONNX OCR recognition model.
#
# Usage:
#   ./scripts/download_ocr_model.sh
#
# Requires:
#   - pip install paddlepaddle paddle2onnx
#
# After running, the model will be at:
#   assets/models/ocr/model.onnx
#   assets/models/ocr/ppocr_keys_v1.txt  (character dictionary)
#   assets/models/ocr/model_config.json  (updated)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OCR_DIR="$PROJECT_ROOT/assets/models/ocr"

# PaddleOCR PP-OCRv4 official download URL
MODEL_ARCHIVE_URL="https://paddleocr.bj.bcebos.com/PP-OCRv4/chinese/ch_PP-OCRv4_rec_infer.tar"
DICT_URL="https://raw.githubusercontent.com/PaddlePaddle/PaddleOCR/release/2.7/ppocr/utils/ppocr_keys_v1.txt"

mkdir -p "$OCR_DIR"

echo "=== OCR Model Downloader ==="
echo "Target directory: $OCR_DIR"
echo ""

# Check for required tools
check_dependencies() {
    local missing=""
    if ! python3 -c "import paddle" 2>/dev/null; then
        missing="$missing paddlepaddle"
    fi
    if ! python3 -c "import paddle2onnx" 2>/dev/null; then
        missing="$missing paddle2onnx"
    fi
    if [ -n "$missing" ]; then
        echo "[!!] Missing dependencies:$missing"
        echo "[!!] Install with: pip install paddlepaddle paddle2onnx"
        return 1
    fi
    return 0
}

# Download and extract model archive
download_model() {
    local archive="$OCR_DIR/ch_PP-OCRv4_rec_infer.tar"
    local extract_dir="$OCR_DIR/ch_PP-OCRv4_rec_infer"

    if [ -f "$OCR_DIR/model.onnx" ] && [ "$(wc -c < "$OCR_DIR/model.onnx")" -gt 1000000 ]; then
        echo "[OK] ONNX model already exists: $OCR_DIR/model.onnx"
        return 0
    fi

    echo "[..] Downloading PaddleOCR PP-OCRv4 model..."
    if ! curl -fsSL --connect-timeout 30 --max-time 300 -o "$archive" "$MODEL_ARCHIVE_URL"; then
        echo "[FAIL] Download failed"
        return 1
    fi
    echo "[OK] Downloaded: $(du -h "$archive" | cut -f1)"

    echo "[..] Extracting..."
    tar -xf "$archive" -C "$OCR_DIR"
    echo "[OK] Extracted to: $extract_dir"

    echo "[..] Converting to ONNX with paddle2onnx..."
    if ! python3 -c "
import paddle2onnx
paddle2onnx.convert(
    model_dir='$extract_dir',
    model_filename='inference.pdmodel',
    params_filename='inference.pdiparams',
    save_file='$OCR_DIR/model.onnx',
    opset_version=11,
    enable_onnx_checker=True
)
print('Conversion successful')
"; then
        echo "[FAIL] ONNX conversion failed"
        return 1
    fi
    echo "[OK] Converted to ONNX: $OCR_DIR/model.onnx"

    # Clean up
    rm -rf "$extract_dir" "$archive"
    echo "[OK] Cleaned up temporary files"
    return 0
}

# Download character dictionary
download_dict() {
    local dict_path="$OCR_DIR/ppocr_keys_v1.txt"
    if [ -f "$dict_path" ] && [ "$(wc -l < "$dict_path")" -gt 100 ]; then
        echo "[OK] Dictionary already exists ($(wc -l < "$dict_path") lines)"
        return 0
    fi

    echo "[..] Downloading character dictionary..."
    if curl -fsSL --connect-timeout 30 --max-time 60 -o "$dict_path" "$DICT_URL"; then
        echo "[OK] Downloaded: $dict_path ($(wc -l < "$dict_path") lines)"
    else
        echo "[WARN] Dictionary download failed. CTC decode will use index-only mode."
    fi
}

# Update model_config.json
update_config() {
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
}

# Main
if ! check_dependencies; then
    echo ""
    echo "To install dependencies, run:"
    echo "  pip install paddlepaddle paddle2onnx"
    exit 1
fi

if ! download_model; then
    echo "[FAIL] Model download/conversion failed"
    exit 1
fi

download_dict
update_config

echo ""
echo "=== Done ==="
echo "Model: $OCR_DIR/model.onnx"
echo "Dict:  $OCR_DIR/ppocr_keys_v1.txt"
echo "Config: $OCR_DIR/model_config.json"
echo ""
echo "Next: flutter build ios --release"
