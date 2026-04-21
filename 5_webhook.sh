#!/bin/bash

echo "📂 Debug output:"
find ./output -type f || true

git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# --- FUNCTION ---
send_webhook() {
    FILE="$1"
    TYPE="$2"
    WEBHOOK="$3"

    URL_FILENAME=$(basename "$FILE")
    SAFE_NAME="${URL_FILENAME%.*}"

    REL_PATH="${FILE#./}"
    RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPOSITORY}/${CURRENT_BRANCH}/${REL_PATH}"

    echo "-----------------------------------------------"
    echo "📦 TYPE: $TYPE"
    echo "📂 FILE PATH: $FILE"
    echo "🌐 REL PATH: $REL_PATH"
    echo "🔗 RAW URL: $RAW_URL"

    git add -f "$FILE"
    git add -f metadata.json

    git commit -m "Upload $TYPE: $SAFE_NAME [skip ci]" || git commit --amend --no-edit
    git push origin "$CURRENT_BRANCH" --force

    echo "⏳ Waiting 5s..."
    sleep 5

    PAYLOAD=$(jq -n \
      --arg url "$RAW_URL" \
      --arg name "$URL_FILENAME" \
      --arg type "$TYPE" \
      '{fileUrl: $url, fileName: $name, type: $type}')

    echo "📡 Sending $TYPE webhook..."

    RESPONSE=$(curl -s -L -X POST \
      "$WEBHOOK" \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD")

    echo "📩 Response:"
    echo "$RESPONSE"
}

# ============================================
# 🔴 STEP 1: REEL FILES
# ============================================

echo ""
echo "🎬 ===== REEL FILES ====="

REEL_FILES=$(find ./output/reel -type f -name "*.mp4" 2>/dev/null)

if [ -z "$REEL_FILES" ]; then
    echo "⚠️ No reel files found"
else
    echo "📂 Reel Paths:"
    echo "$REEL_FILES"

    for FILE in $REEL_FILES; do
        send_webhook "$FILE" "reel" "$WEBHOOK_REEL"
    done
fi

# ============================================
# 🔵 STEP 2: VIDEO FILES
# ============================================

echo ""
echo "🎥 ===== VIDEO FILES ====="

VIDEO_FILES=$(find ./output/video -type f -name "*.mp4" 2>/dev/null)

if [ -z "$VIDEO_FILES" ]; then
    echo "⚠️ No video files found"
else
    echo "📂 Video Paths:"
    echo "$VIDEO_FILES"

    for FILE in $VIDEO_FILES; do
        send_webhook "$FILE" "video" "$WEBHOOK_VIDEO"
    done
fi

echo ""
echo "✨ All done"
