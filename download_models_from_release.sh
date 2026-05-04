#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

RELEASE_TAG="${RELEASE_TAG:-models-v1}"
REPO="${REPO:-hhhaiai/loadmodel}"
ARCHIVE_DIR="${ARCHIVE_DIR:-assets/models_archive}"

cd "$SCRIPT_DIR"

echo "=== Download Model Archives from GitHub Release ==="
echo "Repository: $REPO"
echo "Tag: $RELEASE_TAG"
echo ""

# Check if user is authenticated
if ! gh auth status &>/dev/null; then
    echo "Error: Not authenticated with GitHub"
    echo "Run 'gh auth login' first"
    exit 1
fi

# Create archive directory if not exists
mkdir -p "$ARCHIVE_DIR"

# Download all parts
echo "Downloading release assets..."
gh release download "$RELEASE_TAG" \
    --repo "$REPO" \
    --dir "$ARCHIVE_DIR" \
    --pattern "*.part*" \
    --pattern "*.sha256"

echo ""
echo "Download complete!"
echo "Files in $ARCHIVE_DIR:"
ls -lh "$ARCHIVE_DIR/"
echo ""
echo "Now run ./restore_models.sh to extract"
