#!/bin/bash
# VideoGrab.app 빌드.
#   ./scripts/build.sh          빌드만
#   ./scripts/build.sh install  빌드 후 /Applications 에 설치
#   ./scripts/build.sh zip      빌드 후 릴리스용 build/VideoGrab-<버전>-arm64.zip 생성
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
"$APP/Contents/MacOS/VideoGrab" --selftest
echo "빌드 완료: $APP"

if [[ "${1:-}" == "install" ]]; then
    rm -rf /Applications/VideoGrab.app
    cp -R "$APP" /Applications/
    echo "설치 완료: /Applications/VideoGrab.app"
fi

if [[ "${1:-}" == "zip" ]]; then
    # zip 안 구성: VideoGrab-<버전>/{VideoGrab.app, LICENSE}. 맥 확장 속성(._ 파일)은 뺀다
    VERSION=$(plutil -extract CFBundleShortVersionString raw src/Info.plist)
    NAME="VideoGrab-$VERSION"
    ZIP="build/$NAME-arm64.zip"
    rm -rf "build/$NAME" "$ZIP"
    mkdir "build/$NAME"
    ditto --norsrc --noextattr "$APP" "build/$NAME/VideoGrab.app"
    cp LICENSE "build/$NAME/"
    (cd build && ditto -c -k --norsrc --noextattr --keepParent "$NAME" "$NAME-arm64.zip")
    rm -rf "build/$NAME"
    echo "zip 완료: $ZIP"
    shasum -a 256 "$ZIP"
fi
