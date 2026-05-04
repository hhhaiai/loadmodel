#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ARCHIVE_DIR="${ARCHIVE_DIR:-assets/models_archive}"
RELEASE_TAG="${RELEASE_TAG:-models-v1}"
REPO="${REPO:-hhhaiai/loadmodel}"

cd "$SCRIPT_DIR"

if [ ! -d "$ARCHIVE_DIR" ]; then
    echo "Error: Archive directory not found: $ARCHIVE_DIR"
    echo "Run ./pack_models.sh first to create archive splits"
    exit 1
fi

# Find all split parts
PART_FILES=("$ARCHIVE_DIR"/*.part*)
SHA256_FILE="$ARCHIVE_DIR/assets_models.tar.gz.sha256"

if [ ${#PART_FILES[@]} -eq 0 ] || [ ! -f "${PART_FILES[0]}" ]; then
    echo "Error: No split archive parts found in $ARCHIVE_DIR"
    exit 1
fi

echo "=== Upload Model Archives to GitHub Release ==="
echo "Repository: $REPO"
echo "Tag: $RELEASE_TAG"
echo "Archive directory: $ARCHIVE_DIR"
echo "Parts to upload: ${#PART_FILES[@]}"
echo ""

# Check if user is authenticated
if ! gh auth status &>/dev/null; then
    echo "Error: Not authenticated with GitHub"
    echo "Run 'gh auth login' first"
    exit 1
fi

# Create or update release
echo "Creating/updating release $RELEASE_TAG..."
RELEASE_NOTES="Model assets archive split into parts for easier download.

## Download Instructions
1. Download all part files from this release
2. Place them in \`assets/models_archive/\` directory
3. Run \`./restore_models.sh\` to extract

## Included Models
- Embedding: bge-small-zh-v1.5
- Image Caption: CLIP vision encoder (clip-vit-base-patch32)
- OCR: PaddleOCR PP-OCRv4 (when downloaded)
- STT: Whisper encoder+decoder (when downloaded)
- LLM: Various GGUF models (when downloaded)
"

# Check if release exists
if gh release view "$RELEASE_TAG" --repo "$REPO" &>/dev/null; then
    echo "Release exists, editing..."
    gh release edit "$RELEASE_TAG" \
        --title "Model Assets $RELEASE_TAG" \
        --notes "$RELEASE_NOTES" \
        --repo "$REPO"
else
    echo "Creating new release..."
    gh release create "$RELEASE_TAG" \
        --title "Model Assets $RELEASE_TAG" \
        --notes "$RELEASE_NOTES" \
        --repo "$REPO"
fi

echo "Release created/updated: https://github.com/$REPO/releases/tag/$RELEASE_TAG"
echo ""
echo "Uploading parts..."

# Upload each part
for part in "${PART_FILES[@]}"; do
    if [ -f "$part" ]; then
        echo "  Uploading $(basename "$part")..."
        gh release upload "$RELEASE_TAG" "$part" --repo "$REPO" --clobber
    fi
done

# Upload sha256 if exists
if [ -f "$SHA256_FILE" ]; then
    echo "  Uploading sha256..."
    gh release upload "$RELEASE_TAG" "$SHA256_FILE" --repo "$REPO" --clobber
fi

echo ""
echo "=== Upload Complete ==="
echo "Release URL: https://github.com/$REPO/releases/tag/$RELEASE_TAG"
echo ""
echo "To download on another machine:"
echo "  gh release download $RELEASE_TAG --repo $REPO --dir assets/models_archive"
