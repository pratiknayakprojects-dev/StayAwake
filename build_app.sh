#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

# Universal binary: Apple silicon and Intel
swift build -c release --arch arm64 --arch x86_64
BIN=".build/apple/Products/Release"

APP="StayAwake.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
mkdir -p "$APP/Contents/Library/LaunchDaemons"

cp "$BIN/StayAwake" "$APP/Contents/MacOS/StayAwake"
cp "$BIN/StayAwakeHelper" "$APP/Contents/MacOS/StayAwakeHelper"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp com.pratiknayak.stayawake.helper.plist "$APP/Contents/Library/LaunchDaemons/com.pratiknayak.stayawake.helper.plist"

echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/StayAwake"))"
