#!/bin/bash

# --- 1. FIND MP4 FILE (REEL OR VIDEO) ---
OUT_FILE=$(find ./output -type f -name "*.mp4" | head -n 1)

if [ ! -f "$OUT_FILE" ]; then
    echo "❌ Error: Final video file was not created."
    echo "📂 Debug output folder:"
    find ./output -type f || true
    exit 1
fi

echo "📦 Found file: $OUT_FILE"

URL_FILENAME=$(basename "$OUT_FILE")
SAFE_NAME="${URL_FILENAME%.*}"

# --- 2. GITHUB SETUP ---
echo "-----------------------------------------------"
echo "📤 UPLOADING TO GITHUB REPO..."

git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "🌿 Branch: $CURRENT_BRANCH"

git add -f "$OUT_FILE"
git add -f metadata.json

# --- 3. FIXED RAW URL (IMPORTANT PART) ---
REL_PATH="${OUT_FILE#./}"

RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPOSITORY}/${CURRENT_BRANCH}/${REL_PATH}"

echo "🔗 RAW_URL generated:"
echo "$RAW_URL"

# --- commit + push ---
git commit -m "Refresh: $SAFE_NAME [skip ci]" || git commit --amend --no-edit
git push origin "$CURRENT_BRANCH" --force

# --- 4. WEBHOOK CALL (DUAL) ---
if [ -n "$WEBHOOK_REEL" ] && [ -n "$WEBHOOK_VIDEO" ]; then

    echo "⏳ Waiting 5 seconds for GitHub sync..."
    sleep 5

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
