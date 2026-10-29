#!/bin/bash
# Builds a Release, signs it with the Harbor certificate, zips it and prints
# the SHA-256 for the Harbor catalog.
#
# Signing with the same certificate every time keeps the app's designated
# requirement stable, so macOS keeps the permissions people granted when the
# app updates. Without the certificate the build stays ad-hoc signed.
set -euo pipefail
cd "$(dirname "$0")/.."
NAME=Ferry
IDENTITY="${HARBOR_SIGNING_IDENTITY:-Harbor Apps Code Signing}"
APP="build/release/Build/Products/Release/$NAME.app"

xcodegen generate >/dev/null
xcodebuild -quiet -project "$NAME.xcodeproj" -scheme "$NAME" -configuration Release -derivedDataPath build/release build
if security find-identity -p codesigning | grep -q "$IDENTITY"; then
    codesign --force --deep --sign "$IDENTITY" --preserve-metadata=entitlements,flags "$APP"
else
    echo "warning: '$IDENTITY' isn't in the keychain; the build stays ad-hoc signed" >&2
fi
codesign --verify --deep --strict "$APP"
codesign -d -r- "$APP" 2>&1 | grep designated

ditto -c -k --keepParent "$APP" "build/$NAME.zip"
echo "version $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
shasum -a 256 "build/$NAME.zip"
