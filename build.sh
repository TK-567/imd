#!/bin/bash
set -e

cd "$(dirname "$0")"

APP_NAME="imd"
EXEC_NAME="imd"
SRC="App.swift"
OUT="build"
APP="$OUT/$APP_NAME.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "[1/4] compile Swift"
swiftc -O -parse-as-library \
    -target arm64-apple-macos14.0 \
    "$SRC" \
    -o "$APP/Contents/MacOS/$EXEC_NAME" \
    -framework AppKit -framework SwiftUI -framework WebKit -framework UniformTypeIdentifiers

echo "[2/4] render Info.plist (year-aware copyright)"
YEAR=$(date +%Y)
if [ "$YEAR" -gt 2026 ]; then CPYEAR="2026-$YEAR"; else CPYEAR="2026"; fi
COPYRIGHT="©️${CPYEAR} Thinking（anqi.ssx@163.com）"
sed "s/__COPYRIGHT__/$COPYRIGHT/g" Info.plist > "$APP/Contents/Info.plist"

echo "[3/4] copy resources"
cp Resources/*.js "$APP/Contents/Resources/" 2>/dev/null || true
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null || true

echo "[4/4] ad-hoc sign"
codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo
echo "done: $(pwd)/$APP"
echo "run: open \"$APP\""