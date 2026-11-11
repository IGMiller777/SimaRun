#!/bin/bash
# Builds SimaRun.app in this folder from source. No downloads, no dependencies.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="SimaRun.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/SimaRun" "$APP/Contents/MacOS/SimaRun"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature: signed by this Mac, for this Mac.
codesign --force --sign - "$APP"

echo "Built $(pwd)/$APP"
