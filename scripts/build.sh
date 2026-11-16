#!/bin/bash
# VideoGrab.app 빌드. ./scripts/build.sh install 이면 /Applications 에도 설치한다.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/VideoGrab.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -parse-as-library -target arm64-apple-macos14.0 \
    -o "$APP/Contents/MacOS/VideoGrab" src/VideoGrab.swift
cp src/Info.plist "$APP/Contents/"

# 아이콘: build/AppIcon.icns 가 없을 때만 만든다
if [[ ! -f build/AppIcon.icns ]]; then
    rm -rf build/AppIcon.iconset
    swift scripts/make-icon.swift build/AppIcon.iconset
    iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/"

codesign --force --sign - "$APP"
echo "빌드 완료: $APP"

if [[ "${1:-}" == "install" ]]; then
    rm -rf /Applications/VideoGrab.app
    cp -R "$APP" /Applications/
    echo "설치 완료: /Applications/VideoGrab.app"
fi
