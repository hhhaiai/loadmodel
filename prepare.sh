#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ==================== Configuration ====================
MODELS_MARKER="assets/models/bge-small/model.onnx"
LLAMA_MARKER="third_party/llama.cpp/CMakeLists.txt"

MODELS_ARCHIVE_PREFIX="assets/models_archive/assets_models.tar.gz"
MODELS_OUTPUT_DIR="assets"

LLAMA_ARCHIVE_PREFIX="third_party/llama_cpp_archive/third_party_llama_cpp.tar.gz"
LLAMA_OUTPUT_DIR="third_party"

RELEASE_TAG="${RELEASE_TAG:-models-v1}"
RELEASE_REPO="${RELEASE_REPO:-hhhaiai/loadmodel}"

# ==================== Parse arguments ====================
FORCE=0
SKIP_DOWNLOAD=0

for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        --skip-download) SKIP_DOWNLOAD=1 ;;
        --help|-h)
            echo "Usage: $0 [--force] [--skip-download]"
            echo ""
            echo "One-click project setup: restore models + llama.cpp + flutter pub get"
            echo ""
            echo "Options:"
            echo "  --force          Force re-extraction even if targets exist"
            echo "  --skip-download  Skip GitHub Release download if split parts are missing"
            echo "  --help, -h       Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Run '$0 --help' for usage."
            exit 1
            ;;
    esac
done

# ==================== Helper functions ====================
models_restored() {
    [ -f "$MODELS_MARKER" ]
}

llama_restored() {
    [ -f "$LLAMA_MARKER" ]
}

parts_exist() {
    local prefix="$1"
    [ -f "${prefix}.part000" ]
}

download_release() {
    local pattern="$1"
    local dest_dir="$2"

    if [ "$SKIP_DOWNLOAD" = "1" ]; then
        echo "  Download skipped (--skip-download)."
        return 1
    fi

    if ! command -v gh &>/dev/null; then
        echo "  Error: 'gh' CLI not found. Install from https://cli.github.com/"
        return 1
    fi

    if ! gh auth status &>/dev/null; then
        echo "  Error: Not authenticated with GitHub. Run 'gh auth login' first."
        return 1
    fi

    mkdir -p "$dest_dir"
    echo "  Downloading from GitHub Release ($RELEASE_TAG)..."
    gh release download "$RELEASE_TAG" \
        --repo "$RELEASE_REPO" \
        --dir "$dest_dir" \
        --pattern "$pattern"
    return 0
}

restore_archive() {
    local archive_prefix="$1"
    local output_dir="$2"
    local label="$3"

    if ! parts_exist "$archive_prefix"; then
        echo "  Split parts not found locally."
        local archive_dir
        archive_dir="$(dirname "$archive_prefix")"
        local pattern="*.part* *.sha256"

        if download_release "$pattern" "$archive_dir"; then
            echo "  Download complete."
        else
            echo "  Cannot restore $label: no split parts and download failed/skipped."
            return 1
        fi
    fi

    ARCHIVE_PREFIX="$archive_prefix" \
    ARCHIVE_OUTPUT_DIR="$output_dir" \
    ARCHIVE_KEEP_PARTS=1 \
    "$SCRIPT_DIR/auto_merge.sh"
}

# ==================== Main logic ====================
echo "=========================================="
echo "  ModelLoader - Project Setup"
echo "=========================================="
echo ""

DONE_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

# --- Models ---
echo "[1/3] Models (assets/models/)"
if models_restored && [ "$FORCE" = "0" ]; then
    echo "  Already restored. Skipping."
    SKIP_COUNT=$((SKIP_COUNT + 1))
else
    if restore_archive "$MODELS_ARCHIVE_PREFIX" "$MODELS_OUTPUT_DIR" "models"; then
        echo "  Models restored successfully."
        DONE_COUNT=$((DONE_COUNT + 1))
    else
        echo "  Failed to restore models."
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
fi
echo ""

# --- llama.cpp ---
echo "[2/3] llama.cpp (third_party/llama.cpp/)"
if llama_restored && [ "$FORCE" = "0" ]; then
    echo "  Already restored. Skipping."
    SKIP_COUNT=$((SKIP_COUNT + 1))
else
    if restore_archive "$LLAMA_ARCHIVE_PREFIX" "$LLAMA_OUTPUT_DIR" "llama.cpp"; then
        echo "  llama.cpp restored successfully."
        DONE_COUNT=$((DONE_COUNT + 1))
    else
        echo "  Failed to restore llama.cpp."
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
fi
echo ""

# --- Flutter pub get ---
echo "[3/3] Flutter dependencies"
if command -v flutter &>/dev/null; then
    flutter pub get
    DONE_COUNT=$((DONE_COUNT + 1))
else
    echo "  Flutter not found in PATH. Skipping pub get."
    SKIP_COUNT=$((SKIP_COUNT + 1))
fi
echo ""

# --- Summary ---
echo "=========================================="
echo "  Setup complete!"
echo "  Restored: $DONE_COUNT | Skipped: $SKIP_COUNT | Failed: $FAIL_COUNT"
echo "=========================================="

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
