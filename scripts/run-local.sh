#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/web_url_registration.py Support/Info.plist
if pgrep -x BrowserDaddy >/dev/null; then
    echo "Quit BrowserDaddy before rebuilding the local app."
    exit 1
fi
sh scripts/build-icon.sh
swift build --product BrowserDaddy
bin_path="$(swift build --show-bin-path)"
bundle_path="$PWD/.build/BrowserDaddy.app"
mkdir -p "$bundle_path/Contents/MacOS" "$bundle_path/Contents/Resources"
cp "$bin_path/BrowserDaddy" "$bundle_path/Contents/MacOS/BrowserDaddy"
cp Support/Info.plist "$bundle_path/Contents/Info.plist"
cp Support/BrowserDaddy.icns "$bundle_path/Contents/Resources/BrowserDaddy.icns"
cp -R "$bin_path/BrowserDaddy_BrowserDaddy.bundle" "$bundle_path/Contents/Resources/" 2>/dev/null || true
open -n "$bundle_path" --args "$@"
