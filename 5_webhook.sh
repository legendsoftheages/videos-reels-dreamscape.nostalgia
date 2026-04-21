#!/bin/bash

# --- CHECK REQUIRED SECRETS ---
: "${WEBHOOK_REEL:?Missing WEBHOOK_REEL}"
: "${WEBHOOK_VIDEO:?Missing WEBHOOK_VIDEO}"

# --- 1. FIND MP4 FILE ---
OUT_FILE=$(find ./output -type f -name "*.mp4" | head -n 1)

if [ ! -f "$OUT_FILE" ]; then
    echo "❌ Error: No mp4 file found."
    exit 1
fi

URL_FILENAME=$(basename "$OUT_FILE")
SAFE_NAME="${URL_FILENAME%.*}"

# --- 2. DETECT TYPE ---
if [[ "$OUT_FILE" == *"/reel/"* ]]; then
    TYPE="reel"
elif [[ "$OUT_FILE" == *"/video/"* ]]; then
    TYPE="video"
else
    echo "❌ Unknown folder type"
    exit 1
fi

echo "📦 Detected type: $TYPE"

# --- 3. GITHUB UPLOAD ---
echo "-----------------------------------------------"
echo "📤 UPLOADING TO GITHUB..."

git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

git add -f "$OUT_FILE"
git add -f metadata.json

RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPOSITORY}/${CURRENT_BRANCH}/output/${URL_FILENAME}"

git commit -m "Upload $TYPE: $SAFE_NAME [skip ci]" || git commit --amend --no-edit
git push origin "$CURRENT_BRANCH" --force

echo "⏳ Waiting for GitHub sync..."
sleep 8

# --- 4. BUILD PAYLOAD ---
PAYLOAD=$(jq -n \
  --arg url "$RAW_URL" \
  --arg name "$URL_FILENAME" \
  --arg type "$TYPE" \
  '{fileUrl: $url, fileName: $name, type: $type}')

# --- 5. SEND WEBHOOKS (BOTH) ---

echo "📡 Sending Reel Webhook..."
RESPONSE_REEL=$(curl -s -L -X POST \
  "$WEBHOOK_REEL" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

echo "📩 Reel Response:"
echo "$RESPONSE_REEL"

echo "📡 Sending Video Webhook..."
RESPONSE_VIDEO=$(curl -s -L -X POST \
  "$WEBHOOK_VIDEO" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

echo "📩 Video Response:"
echo "$RESPONSE_VIDEO"

echo "-----------------------------------------------"
echo "✨ Done"
