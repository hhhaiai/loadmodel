#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Incremental check: skip if llama.cpp already restored
FORCE=0
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
    esac
done

if [ -f "third_party/llama.cpp/CMakeLists.txt" ] && [ "$FORCE" = "0" ]; then
    echo "llama.cpp already restored. Use --force to re-extract."
    exit 0
fi

ARCHIVE_PREFIX="${ARCHIVE_PREFIX:-third_party/llama_cpp_archive/third_party_llama_cpp.tar.gz}"
ARCHIVE_OUTPUT_DIR="${ARCHIVE_OUTPUT_DIR:-third_party}"
ARCHIVE_KEEP_PARTS="${ARCHIVE_KEEP_PARTS:-1}"

ARCHIVE_PREFIX="$ARCHIVE_PREFIX" \
ARCHIVE_OUTPUT_DIR="$ARCHIVE_OUTPUT_DIR" \
ARCHIVE_KEEP_PARTS="$ARCHIVE_KEEP_PARTS" \
"$SCRIPT_DIR/auto_merge.sh"
