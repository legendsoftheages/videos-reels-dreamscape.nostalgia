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

FINAL_OUT="$OUT_DIR/$FILENAME"

# 2. VERIFY ASSETS
if [ ! -f "$AUDIO" ]; then 
    echo "❌ Missing audio"
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
scale=1200:1960:force_original_aspect_ratio=increase,
zoompan=z='zoom+0.0008':d=1:s=1080x1920:fps=30,
rotate='0.04*sin(2*PI*t/5)':fillcolor=black@0,
crop=1080:1920[bg];

[cover]scale=900:900[fg];

[bg][fg]overlay=(W-w)/2:(H-h)/2-200[vbase];

[2:v]scale=200:-1[logo];

[logo]fade=t=in:st=$LOGO_START:d=0.6:alpha=1,
fade=t=out:st=$FADE_OUT_TIME:d=2:alpha=1[logofaded];

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

echo "✅ Success: $FINAL_OUT"

# 5. GITHUB UPLOAD
echo "-----------------------------------------------"
echo "📤 UPLOADING TO GITHUB REPO..."

git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "🌿 Detected branch: $CURRENT_BRANCH"

if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ GITHUB_TOKEN is not set"
    exit 1
fi

git remote set-url origin https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git

git add "$FINAL_OUT"

git commit -m "Auto render: $FILENAME" || echo "⚠️ Nothing to commit"

git push origin "$CURRENT_BRANCH"

echo "✅ Uploaded to GitHub successfully"
