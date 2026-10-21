#!/bin/bash
# After `gh release create vX.Y.Z ...`, bump the Homebrew cask to match.
# Usage: scripts/update-cask.sh [path-to-tap]   (default: ../homebrew-stayawake)
set -euo pipefail
cd "$(dirname "$0")/.."
TAP="${1:-../homebrew-stayawake}"
V=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)
URL="https://github.com/pratiknayakprojects-dev/StayAwake/releases/download/v$V/StayAwake.dmg"
SHA=$(curl -fsSL "$URL" | shasum -a 256 | cut -d' ' -f1)   # hash what users actually download
sed -i '' -E "s/^  version \".*\"/  version \"$V\"/; s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$TAP/Casks/stayawake.rb"
cd "$TAP" && git add Casks/stayawake.rb && git commit -m "stayawake $V" && git push
