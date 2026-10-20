#!/bin/bash
# Build, sign, notarize and package StayAwake.dmg.
# Usage: IDENTITY="Developer ID Application: Your Name (5UZSA4DB7V)" PROFILE=notary ./release.sh
# PROFILE is a notarytool keychain profile (xcrun notarytool store-credentials notary ...).
set -euo pipefail
cd "$(dirname "$0")"
: "${IDENTITY:?set IDENTITY}" "${PROFILE:?set PROFILE}"

./build_app.sh
APP=StayAwake.app
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP/Contents/MacOS/StayAwakeHelper"
codesign --force --options runtime --timestamp --entitlements StayAwake.entitlements --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"

ditto -c -k --keepParent "$APP" StayAwake.zip
xcrun notarytool submit StayAwake.zip --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"

rm -rf dmg-stage StayAwake.dmg && mkdir dmg-stage
cp -R "$APP" dmg-stage/ && ln -s /Applications dmg-stage/Applications
hdiutil create -volname StayAwake -srcfolder dmg-stage -ov -format UDZO StayAwake.dmg
rm -rf dmg-stage
codesign --force --timestamp --sign "$IDENTITY" StayAwake.dmg
xcrun notarytool submit StayAwake.dmg --keychain-profile "$PROFILE" --wait
xcrun stapler staple StayAwake.dmg
spctl -a -t open --context context:primary-signature -v StayAwake.dmg
echo "Done: StayAwake.dmg ready to upload as v$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)"
