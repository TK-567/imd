#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "[0/5] rebuild icon (with margin)"
swiftc -O make_icon.swift -o make_icon_bin -framework AppKit 2>/dev/null
./make_icon_bin icon_1024.png
rm -rf icon.iconset AppIcon.icns
mkdir -p icon.iconset
M=icon_1024.png
sips -z 16 16     "$M" --out icon.iconset/icon_16x16.png        >/dev/null
sips -z 32 32     "$M" --out icon.iconset/icon_16x16@2x.png     >/dev/null
sips -z 32 32     "$M" --out icon.iconset/icon_32x32.png        >/dev/null
sips -z 64 64     "$M" --out icon.iconset/icon_32x32@2x.png     >/dev/null
sips -z 128 128   "$M" --out icon.iconset/icon_128x128.png       >/dev/null
sips -z 256 256   "$M" --out icon.iconset/icon_128x128@2x.png   >/dev/null
sips -z 256 256   "$M" --out icon.iconset/icon_256x256.png       >/dev/null
sips -z 512 512   "$M" --out icon.iconset/icon_256x256@2x.png   >/dev/null
sips -z 512 512   "$M" --out icon.iconset/icon_512x512.png       >/dev/null
sips -z 1024 1024 "$M" --out icon.iconset/icon_512x512@2x.png    >/dev/null
iconutil -c icns icon.iconset -o AppIcon.icns

echo "[1/5] build app"
./build.sh

echo "[2/5] background"
swiftc -O make_bg.swift -o make_bg_bin -framework AppKit 2>/dev/null
./make_bg_bin .dmg_bg.png

echo "[3/5] create dmg via dmgbuild"
python3 make_dmg.py

echo "[4/5] verify"
hdiutil verify "dist/imd-1.1.0.dmg" >/dev/null

echo "[5/5] clean quarantine"
xattr -cr "dist/imd-1.1.0.dmg" 2>/dev/null || true

echo
echo "done: $(pwd)/dist/imd-1.1.0.dmg"
ls -lh dist/imd-1.1.0.dmg
