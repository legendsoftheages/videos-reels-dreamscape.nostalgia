#!/bin/bash

# --- 1. FIND OUTPUT FILE ---
OUT_FILE=$(find ./output -type f -name "*.mp4" | head -n 1)

if [ ! -f "$OUT_FILE" ]; then
    echo "❌ Error: Final video file was not created."
    exit 1
fi

URL_FILENAME=$(basename "$OUT_FILE")
SAFE_NAME="${URL_FILENAME%.*}"

# --- 2. DETECT TYPE (reel or video) ---
if [[ "$OUT_FILE" == *"/reel/"* ]]; then
    WEBHOOK_URL="$WEBHOOK_REEL"
    TYPE="reel"
elif [[ "$OUT_FILE" == *"/video/"* ]]; then
    WEBHOOK_URL="$WEBHOOK_VIDEO"
    TYPE="video"
else
    echo "❌ Unknown output folder"
    exit 1
fi

echo "📦 Detected type: $TYPE"

# --- 3. GITHUB UPLOAD ---
echo "-----------------------------------------------"
echo "📤 UPLOADING TO GITHUB REPO..."

git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

git add -f "$OUT_FILE"
git add -f metadata.json

RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPOSITORY}/${CURRENT_BRANCH}/output/${URL_FILENAME}"

git commit -m "Upload $TYPE: $SAFE_NAME [skip ci]" || git commit --amend --no-edit
git push origin "$CURRENT_BRANCH" --force

# --- 4. WEBHOOK CALL ---
if [ -n "$WEBHOOK_URL" ]; then
    echo "⏳ Waiting 5 seconds..."
    sleep 5

    echo "📡 Sending Webhook for $TYPE"

    PAYLOAD=$(jq -n --arg url "$RAW_URL" --arg name "$URL_FILENAME" --arg type "$TYPE" \
        '{fileUrl: $url, fileName: $name, type: $type}')

    RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
        -d "$PAYLOAD" "$WEBHOOK_URL")

    echo "📩 Response: $RESPONSE"
fi

echo "-----------------------------------------------"
