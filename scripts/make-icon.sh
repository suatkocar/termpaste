#!/bin/bash
# Regenerates Resources/AppIcon.icns from Resources/AppIcon.svg. Needs rsvg-convert
# (brew install librsvg); the build itself only copies the committed .icns.
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
command -v rsvg-convert >/dev/null || { printf 'rsvg-convert not found: brew install librsvg\n' >&2; exit 1; }
work_dir="$(mktemp -d)"
trap 'rm -r "$work_dir"' EXIT
iconset="$work_dir/AppIcon.iconset"
mkdir "$iconset"
for size in 16 32 128 256 512; do
    rsvg-convert -w "$size" -h "$size" "$repo_dir/Resources/AppIcon.svg" -o "$iconset/icon_${size}x${size}.png"
    rsvg-convert -w $((size * 2)) -h $((size * 2)) "$repo_dir/Resources/AppIcon.svg" -o "$iconset/icon_${size}x${size}@2x.png"
done
iconutil -c icns "$iconset" -o "$repo_dir/Resources/AppIcon.icns"
printf 'Wrote %s\n' "$repo_dir/Resources/AppIcon.icns"
