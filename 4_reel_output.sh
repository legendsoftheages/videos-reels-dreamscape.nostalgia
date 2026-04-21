#!/bin/bash

# --- CONFIG ---
AUDIO="./assets/trim_audio/trim_audio.mp3"
IMAGE="./assets/image/image.jpg"
LOGO="./assets/spotify.png"
METADATA="metadata.json"
OUT_DIR="./output/reel"

mkdir -p "$OUT_DIR"

# 1. READ METADATA
if [ -f "$METADATA" ]; then
    ARTIST=$(jq -r '.artist // "Artist"' "$METADATA" | tr ' ' '_')
    TRACK=$(jq -r '.track // "Track"' "$METADATA" | tr ' ' '_')
    FILENAME="${ARTIST}_-_${TRACK}.mp4"
else
    FILENAME="output.mp4"
fi
# --- CHECK REQUIRED SECRETS ---
: "${WEBHOOK_REEL:?Missing WEBHOOK_REEL}"
: "${WEBHOOK_VIDEO:?Missing WEBHOOK_VIDEO}"

FINAL_OUT="$OUT_DIR/$FILENAME"
# --- 1. FIND MP4 FILE ---
OUT_FILE=$(find ./output -type f -name "*.mp4" | head -n 1)

# 2. VERIFY ASSETS
if [ ! -f "$AUDIO" ]; then 
    echo "❌ Missing audio"
if [ ! -f "$OUT_FILE" ]; then
    echo "❌ Error: No mp4 file found."
    exit 1
fi

# 3. DURATION CALCULATION
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO")

LOGO_START=$(echo "$DURATION / 2" | bc -l)

FADE_DURATION=1.5
FADE_OUT_TIME=$(echo "$DURATION - $FADE_DURATION" | bc -l)

echo "🎬 Rendering: $FILENAME"
echo "⏱️ Duration: $DURATION | Logo at: $LOGO_START"

# 4. RENDER VIDEO
ffmpeg -y \
-t "$DURATION" -loop 1 -i "$IMAGE" \
-t "$DURATION" -i "$AUDIO" \
-t "$DURATION" -loop 1 -i "$LOGO" \
-filter_complex "
[0:v]format=yuv420p,
crop=min(iw\,ih):min(iw\,ih),
scale=1080:1080,
eq=saturation=1.2:contrast=1.05[cover];

[0:v]format=yuv420p,
crop=min(iw\,ih):min(iw\,ih),
scale=300:300,
gblur=sigma=15,
scale=1200:2000:force_original_aspect_ratio=increase,
zoompan=z='zoom+0.008':d=1:s=1200x2000:fps=30,
rotate='0.04*sin(2*PI*t/5)':fillcolor=black@0,
crop=1080:1920[bg];

[cover]scale=900:900[fg];

[bg][fg]overlay=(W-w)/2:(H-h)/2-200[vbase];

[2:v]scale=200:-1[logo];

[logo]fade=t=in:st=$LOGO_START:d=0.6:alpha=1,
fade=t=out:st=$FADE_OUT_TIME:d=2:alpha=1[logofaded];
URL_FILENAME=$(basename "$OUT_FILE")
SAFE_NAME="${URL_FILENAME%.*}"

[vbase][logofaded]overlay=(W-w)/2:H-h-60:enable='between(t,$LOGO_START,$DURATION)',
format=yuv420p,
fade=t=in:st=0:d=$FADE_DURATION,
fade=t=out:st=$FADE_OUT_TIME:d=$FADE_DURATION[v];

[1:a]afade=t=in:st=0:d=1.5,
afade=t=out:st=$FADE_OUT_TIME:d=2[a]
" \
-map "[v]" \
-map "[a]" \
-c:v libx264 -preset veryfast -crf 22 \
-pix_fmt yuv420p \
-c:a aac -b:a 192k \
"$FINAL_OUT"
# --- 2. DETECT TYPE FROM FOLDER ---
if [[ "$OUT_FILE" == *"/reel/"* ]]; then
    WEBHOOK_URL="$WEBHOOK_REEL"
    TYPE="reel"
elif [[ "$OUT_FILE" == *"/video/"* ]]; then
    WEBHOOK_URL="$WEBHOOK_VIDEO"
    TYPE="video"
else
    echo "❌ Unknown folder type"
    exit 1
fi

echo "✅ Success: $FINAL_OUT"
echo "📦 Detected type: $TYPE"

# 5. GITHUB UPLOAD
# --- 3. GITHUB UPLOAD ---
echo "-----------------------------------------------"
echo "📤 UPLOADING TO GITHUB REPO..."
echo "📤 UPLOADING TO GITHUB..."

git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "🌿 Detected branch: $CURRENT_BRANCH"

if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ GITHUB_TOKEN is not set"
    exit 1
fi
git add -f "$OUT_FILE"
git add -f metadata.json

git remote set-url origin https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git
RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPOSITORY}/${CURRENT_BRANCH}/output/${URL_FILENAME}"

git add "$FINAL_OUT"
git commit -m "Upload $TYPE: $SAFE_NAME [skip ci]" || git commit --amend --no-edit
git push origin "$CURRENT_BRANCH" --force

git commit -m "Auto render: $FILENAME" || echo "⚠️ Nothing to commit"
# --- 4. WEBHOOK CALL ---
if [ -n "$WEBHOOK_URL" ]; then
    echo "⏳ Waiting 5 seconds..."
    sleep 5

git push origin "$CURRENT_BRANCH"
    echo "📡 Sending webhook for $TYPE"

echo "✅ Uploaded to GitHub successfully"
    PAYLOAD=$(jq -n \
        --arg url "$RAW_URL" \
        --arg name "$URL_FILENAME" \
        --arg type "$TYPE" \
        '{fileUrl: $url, fileName: $name, type: $type}')

    RESPONSE=$(curl -L -s -X POST \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" \
        "$WEBHOOK_URL")

    echo "📩 Response:"
    echo "$RESPONSE"
fi

echo "-----------------------------------------------"
echo "✨ Done"
