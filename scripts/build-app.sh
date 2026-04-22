#!/usr/bin/env bash
# Build SpacesBar.app unsigned and package it as a zip.
#
# Usage: scripts/build-app.sh <version>
# Outputs:
#   dist/SpacesBar.app
#   dist/SpacesBar-<version>-arm64.zip
set -euo pipefail

VERSION="${1:?usage: build-app.sh <version>}"
BUILD_DIR="build"
DIST_DIR="dist"
APP_NAME="SpacesBar"

rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$DIST_DIR"

xcodebuild \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    -destination 'generic/platform=macOS' \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$VERSION" \
    build | tee build.log

APP_PATH="$BUILD_DIR/Build/Products/Release/${APP_NAME}.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "Build failed: $APP_PATH not found" >&2
    exit 1
fi

cp -R "$APP_PATH" "$DIST_DIR/${APP_NAME}.app"

ZIP_NAME="${APP_NAME}-${VERSION}-arm64.zip"
(cd "$DIST_DIR" && /usr/bin/ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}.app" "$ZIP_NAME")

shasum -a 256 "$DIST_DIR/$ZIP_NAME" | tee "$DIST_DIR/$ZIP_NAME.sha256"
echo "Built $DIST_DIR/$ZIP_NAME"
