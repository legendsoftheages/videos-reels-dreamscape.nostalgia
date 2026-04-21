#!/bin/bash

echo "-----------------------------------------------"
echo "📤 UPLOADING TO GITHUB..."

git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "🌿 Branch: $CURRENT_BRANCH"

# --- FUNCTION TO PROCESS FILE ---
process_file() {
    FILE_PATH="$1"
    TYPE="$2"
    WEBHOOK="$3"

    if [ ! -f "$FILE_PATH" ]; then
        return
    fi

    echo "📦 Processing $TYPE: $FILE_PATH"

    URL_FILENAME=$(basename "$FILE_PATH")
    SAFE_NAME="${URL_FILENAME%.*}"

    git add -f "$FILE_PATH"
    git add -f metadata.json

    REL_PATH="${FILE_PATH#./}"
    RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPOSITORY}/${CURRENT_BRANCH}/${REL_PATH}"

    echo "🔗 RAW_URL:"
    echo "$RAW_URL"

    git commit -m "Upload $TYPE: $SAFE_NAME [skip ci]" || git commit --amend --no-edit
    git push origin "$CURRENT_BRANCH" --force

    echo "⏳ Waiting 5 seconds..."
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

    echo "📩 $TYPE Response:"
    echo "$RESPONSE"

    echo "-----------------------------------------------"
}

# --- PROCESS REEL FILES ---
if [ -n "$WEBHOOK_REEL" ]; then
    for file in ./output/reel/*.mp4; do
        [ -e "$file" ] || continue
        process_file "$file" "reel" "$WEBHOOK_REEL"
    done
fi

# --- PROCESS VIDEO FILES ---
if [ -n "$WEBHOOK_VIDEO" ]; then
    for file in ./output/video/*.mp4; do
        [ -e "$file" ] || continue
        process_file "$file" "video" "$WEBHOOK_VIDEO"
    done
fi

echo "✨ Done"
