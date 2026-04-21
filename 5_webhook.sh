#!/bin/bash

# --- 1. SETUP FILENAMES ---
OUT_FILE=$(ls ./output/*.mp4 2>/dev/null | head -n 1)
if [ ! -f "$OUT_FILE" ]; then
    echo "❌ Error: Final video file was not created."
    exit 1
fi

URL_FILENAME=$(basename "$OUT_FILE")
SAFE_NAME="${URL_FILENAME%.*}"

# --- 2. GITHUB UPLOAD ---
echo "-----------------------------------------------"
echo "📤 UPLOADING TO GITHUB REPO..."

git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "🌿 Detected branch: $CURRENT_BRANCH"

# Clean output except current file
find ./output -type f ! -name "$URL_FILENAME" -delete

# Force add
git add -f "$OUT_FILE"
git add -f metadata.json

RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPOSITORY}/${CURRENT_BRANCH}/output/${URL_FILENAME}"

echo "⚙️ Force pushing to $CURRENT_BRANCH..."
git commit -m "Refresh Reel: $SAFE_NAME [skip ci]" || git commit --amend --no-edit
git push origin "$CURRENT_BRANCH" --force

# --- 3. WEBHOOK CALL (FIXED DUAL VERSION) ---
if [ -n "$WEBHOOK_REEL" ] && [ -n "$WEBHOOK_VIDEO" ]; then

    echo "⏳ Waiting 5 seconds for GitHub sync..."
    sleep 5

    echo "📡 Sending Webhook Payload..."

    PAYLOAD=$(jq -n \
      --arg url "$RAW_URL" \
      --arg name "$URL_FILENAME" \
      '{fileUrl: $url, fileName: $name}')

    # --- REEL WEBHOOK ---
    echo "📡 Sending Reel Webhook..."
    RESPONSE_REEL=$(curl -s -L -X POST \
      "$WEBHOOK_REEL" \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD")

    echo "📩 Reel Response:"
    echo "$RESPONSE_REEL"

    # --- VIDEO WEBHOOK ---
    echo "📡 Sending Video Webhook..."
    RESPONSE_VIDEO=$(curl -s -L -X POST \
      "$WEBHOOK_VIDEO" \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD")

    echo "📩 Video Response:"
    echo "$RESPONSE_VIDEO"

else
    echo "❌ Missing WEBHOOK_REEL or WEBHOOK_VIDEO"
fi

echo "-----------------------------------------------"
echo "✨ Process Complete."
