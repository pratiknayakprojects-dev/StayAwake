#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="StayAwake.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
mkdir -p "$APP/Contents/Library/LaunchDaemons"

cp .build/release/StayAwake "$APP/Contents/MacOS/StayAwake"
cp .build/release/StayAwakeHelper "$APP/Contents/MacOS/StayAwakeHelper"
cp Info.plist "$APP/Contents/Info.plist"
cp com.pratiknayak.stayawake.helper.plist "$APP/Contents/Library/LaunchDaemons/com.pratiknayak.stayawake.helper.plist"

echo "Built $APP"
