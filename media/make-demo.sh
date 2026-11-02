#!/bin/zsh
# Renders media/demo.gif and media/demo.mp4 (needs ffmpeg: brew install ffmpeg).
set -euo pipefail
cd "$(dirname "$0")"
FRAMES=$(mktemp -d)
trap 'rm -rf "$FRAMES"' EXIT

swiftc -O render-demo.swift -o "$FRAMES/render" -framework AppKit
"$FRAMES/render" "$FRAMES"

ffmpeg -loglevel error -y -framerate 30 -i "$FRAMES/frame_%04d.png" \
  -c:v libx264 -pix_fmt yuv420p -crf 18 -movflags +faststart demo.mp4

ffmpeg -loglevel error -y -framerate 30 -i "$FRAMES/frame_%04d.png" \
  -vf "fps=20,scale=720:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a" \
  -loop 0 demo.gif

ls -lh demo.gif demo.mp4
