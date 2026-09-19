#!/bin/sh
# Reproducible macOS representations; source artwork is retained unchanged.
set -eu
cd "$(dirname "$0")/.."
iconset="$PWD/.build/BrowserDaddy.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Sources/BrowserDaddy/Resources/BrowserDaddyIcon.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" Sources/BrowserDaddy/Resources/BrowserDaddyIcon.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o Support/BrowserDaddy.icns
