#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
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
# Sparkle is dynamic — the linker rpath expects it in Contents/Frameworks.
# Fresh copy each run: cp -R merges into an existing dir and was leaving
# flattened framework contents alongside it (breaks codesign --deep).
rm -rf "$bundle_path/Contents/Frameworks"
mkdir -p "$bundle_path/Contents/Frameworks"
cp -R "$bin_path/Sparkle.framework" "$bundle_path/Contents/Frameworks/" 2>/dev/null || true
# TCC (Automation consent etc.) keys grants to the signing identity — an
# ad-hoc signature gets a new identity every build, silently dropping grants.
# A stable development signature keeps them across rebuilds.
identity="$(security find-identity -v -p codesigning | grep -m1 'Apple Development' | sed 's/.*"\(.*\)"/\1/' || true)"
if [ -n "$identity" ]; then
    codesign --force --deep --sign "$identity" "$bundle_path" 2>/dev/null || true
fi
open -n "$bundle_path" --args "$@"
