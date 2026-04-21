#!/bin/bash

echo "📂 Debug output:"
find ./output -type f || true

git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

FILES=$(find ./output -type f -name "*.mp4")

if [ -z "$FILES" ]; then
    echo "❌ No MP4 files found"
    exit 1
fi

for FILE in $FILES; do

    echo "-----------------------------------------------"
    echo "📦 Processing: $FILE"

    URL_FILENAME=$(basename "$FILE")
    SAFE_NAME="${URL_FILENAME%.*}"

    # --- Detect type ---
    if [[ "$FILE" == *"/reel/"* ]]; then
        WEBHOOK="$WEBHOOK_REEL"
        TYPE="reel"
    elif [[ "$FILE" == *"/video/"* ]]; then
        WEBHOOK="$WEBHOOK_VIDEO"
        TYPE="video"
    else
        echo "⚠️ Unknown type, skipping"
        continue
    fi

    echo "📌 Type detected: $TYPE"

    git add -f "$FILE"
    git add -f metadata.json

    REL_PATH="${FILE#./}"
    RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPOSITORY}/${CURRENT_BRANCH}/${REL_PATH}"

    echo "🔗 RAW_URL:"
    echo "$RAW_URL"

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

done

echo "✨ Done"
