#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ARCHIVE_PREFIX="${ARCHIVE_PREFIX:-third_party/llama_cpp_archive/third_party_llama_cpp.tar.gz}"
ARCHIVE_OUTPUT_DIR="${ARCHIVE_OUTPUT_DIR:-third_party}"
ARCHIVE_KEEP_PARTS="${ARCHIVE_KEEP_PARTS:-1}"

cd "$SCRIPT_DIR"

ARCHIVE_PREFIX="$ARCHIVE_PREFIX" \
ARCHIVE_OUTPUT_DIR="$ARCHIVE_OUTPUT_DIR" \
ARCHIVE_KEEP_PARTS="$ARCHIVE_KEEP_PARTS" \
"$SCRIPT_DIR/auto_merge.sh"
