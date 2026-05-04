#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Incremental check: skip if models already restored
FORCE=0
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
    esac
done

if [ -f "assets/models/bge-small/model.onnx" ] && [ "$FORCE" = "0" ]; then
    echo "Models already restored. Use --force to re-extract."
    exit 0
fi

ARCHIVE_PREFIX="${ARCHIVE_PREFIX:-assets/models_archive/assets_models.tar.gz}"
ARCHIVE_OUTPUT_DIR="${ARCHIVE_OUTPUT_DIR:-assets}"
ARCHIVE_KEEP_PARTS="${ARCHIVE_KEEP_PARTS:-1}"

ARCHIVE_PREFIX="$ARCHIVE_PREFIX" \
ARCHIVE_OUTPUT_DIR="$ARCHIVE_OUTPUT_DIR" \
ARCHIVE_KEEP_PARTS="$ARCHIVE_KEEP_PARTS" \
"$SCRIPT_DIR/auto_merge.sh"
