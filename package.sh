#!/bin/bash

# Configuration
APP_NAME="chronote"
PROJECT_NAME="chronote.xcodeproj"
SCHEME="time"
DMG_NAME="Chronote.dmg"
BUILD_DIR="build_output"
STAGING_DIR="dmg_staging"

# Clean previous builds
echo "Cleaning..."
rm -rf "$BUILD_DIR"
rm -rf "$STAGING_DIR"
rm -f "$DMG_NAME"

# Build the project
echo "Building Project..."
xcodebuild -project "$PROJECT_NAME" \
           -scheme "$SCHEME" \
           -configuration Release \
           -derivedDataPath "$BUILD_DIR" \
           build

if [ $? -ne 0 ]; then
    echo "Error: Build failed."
    exit 1
fi

# Locate the built app
APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App bundle not found at $APP_PATH"
    exit 1
fi

# Prepare staging directory for DMG
echo "Preparing DMG contents..."
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Create DMG
echo "Creating DMG..."
hdiutil create -volname "$APP_NAME" \
               -srcfolder "$STAGING_DIR" \
               -ov -format UDZO \
               "$DMG_NAME"

if [ $? -eq 0 ]; then
    echo "==============================================="
    echo "Success! DMG created at: $(pwd)/$DMG_NAME"
    echo "==============================================="
    
    # Cleanup
    rm -rf "$BUILD_DIR"
    rm -rf "$STAGING_DIR"
else
    echo "Error: Failed to create DMG."
    exit 1
fi
