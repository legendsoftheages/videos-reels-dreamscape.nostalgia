#!/bin/bash

echo "📂 Debug output:"
find ./output -type f || true

git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# ==================================================
# 🔴 REEL WEBHOOK SECTION
# ==================================================

echo ""
echo "🎬 ===== REEL SECTION ====="

REEL_FILES=$(find ./output/reel -type f -name "*.mp4" 2>/dev/null)

if [ -z "$REEL_FILES" ]; then
    echo "⚠️ No reel files found"
else
    echo "📂 Reel files:"
    echo "$REEL_FILES"

    for FILE in $REEL_FILES; do

        echo "-----------------------------------------------"
        echo "📦 REEL FILE: $FILE"

        URL_FILENAME=$(basename "$FILE")
        SAFE_NAME="${URL_FILENAME%.*}"

        REL_PATH="${FILE#./}"
        RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPOSITORY}/${CURRENT_BRANCH}/${REL_PATH}"

        echo "🔗 REEL RAW_URL:"
        echo "$RAW_URL"

        git add -f "$FILE"
        git add -f metadata.json

        git commit -m "Upload REEL: $SAFE_NAME [skip ci]" || git commit --amend --no-edit
        git push origin "$CURRENT_BRANCH" --force

        echo "⏳ Waiting 5s..."
        sleep 5

        PAYLOAD=$(jq -n \
          --arg url "$RAW_URL" \
          --arg name "$URL_FILENAME" \
          '{fileUrl: $url, fileName: $name}')

        echo "📡 Sending REEL webhook..."

        RESPONSE=$(curl -s -L -X POST \
          "$WEBHOOK_REEL" \
          -H "Content-Type: application/json" \
          -d "$PAYLOAD")

        echo "📩 REEL Response:"
        echo "$RESPONSE"

    done
fi

# ==================================================
# 🔵 VIDEO WEBHOOK SECTION
# ==================================================

echo ""
echo "🎥 ===== VIDEO SECTION ====="

VIDEO_FILES=$(find ./output/video -type f -name "*.mp4" 2>/dev/null)

if [ -z "$VIDEO_FILES" ]; then
    echo "⚠️ No video files found"
else
    echo "📂 Video files:"
    echo "$VIDEO_FILES"

    for FILE in $VIDEO_FILES; do

        echo "-----------------------------------------------"
        echo "📦 VIDEO FILE: $FILE"

        URL_FILENAME=$(basename "$FILE")
        SAFE_NAME="${URL_FILENAME%.*}"

        REL_PATH="${FILE#./}"
        RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPOSITORY}/${CURRENT_BRANCH}/${REL_PATH}"

        echo "🔗 VIDEO RAW_URL:"
        echo "$RAW_URL"

        git add -f "$FILE"
        git add -f metadata.json

        git commit -m "Upload VIDEO: $SAFE_NAME [skip ci]" || git commit --amend --no-edit
        git push origin "$CURRENT_BRANCH" --force

        echo "⏳ Waiting 5s..."
        sleep 5

        PAYLOAD=$(jq -n \
          --arg url "$RAW_URL" \
          --arg name "$URL_FILENAME" \
          '{fileUrl: $url, fileName: $name}')

        echo "📡 Sending VIDEO webhook..."

        RESPONSE=$(curl -s -L -X POST \
          "$WEBHOOK_VIDEO" \
          -H "Content-Type: application/json" \
          -d "$PAYLOAD")

        echo "📩 VIDEO Response:"
        echo "$RESPONSE"

    done
fi

echo ""
echo "✨ DONE"
