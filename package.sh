#!/bin/bash

# Configuration
APP_NAME="chronote"
PROJECT_NAME="chronote.xcodeproj"
SCHEME="chronote"
BUILD_DIR="build_output"
STAGING_DIR="dmg_staging"
CLI_OUT_DIR="build/cli-dist"
DIST_DIR="dist"

# Function to increment build number
increment_build_number() {
    echo "Incrementing build number..."
    
    # Read current build number from project.pbxproj
    PBXPROJ="$PROJECT_NAME/project.pbxproj"
    CURRENT_BUILD=$(grep -m 1 "CURRENT_PROJECT_VERSION = " "$PBXPROJ" | sed 's/.*= \(.*\);/\1/')
    NEW_BUILD=$((CURRENT_BUILD + 1))
    
    echo "Current build: $CURRENT_BUILD"
    echo "New build: $NEW_BUILD"
    
    # Update all occurrences of CURRENT_PROJECT_VERSION
    sed -i.bak "s/CURRENT_PROJECT_VERSION = $CURRENT_BUILD;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PBXPROJ"
    rm -f "$PBXPROJ.bak"
    
    echo "Build number updated to $NEW_BUILD"
}

# Function to build for specific architecture
build_for_architecture() {
    local ARCH=$1
    local ARCH_NAME=$2
    local BUILD_PATH="${BUILD_DIR}_${ARCH_NAME}"
    
    echo "==============================================="
    echo "Building for $ARCH_NAME ($ARCH)..."
    echo "==============================================="
    
    # Clean previous build for this architecture
    rm -rf "$BUILD_PATH"
    
    # Build the project for specific architecture
    xcodebuild -project "$PROJECT_NAME" \
               -scheme "$SCHEME" \
               -configuration Release \
               -derivedDataPath "$BUILD_PATH" \
               -arch "$ARCH" \
               ONLY_ACTIVE_ARCH=NO \
               build
    
    if [ $? -ne 0 ]; then
        echo "Error: Build failed for $ARCH_NAME."
        return 1
    fi
    
    # Locate the built app
    APP_PATH="$BUILD_PATH/Build/Products/Release/$APP_NAME.app"
    
    if [ ! -d "$APP_PATH" ]; then
        echo "Error: App bundle not found at $APP_PATH"
        return 1
    fi
    
    # Embed architecture-specific CLI binary inside app bundle resources
    local EMBEDDED_CLI_PATH="$APP_PATH/Contents/Resources/chronote-cli"
    if [ "$ARCH_NAME" = "ARM64" ] && [ -f "$CLI_OUT_DIR/chronote-cli-arm64" ]; then
        cp "$CLI_OUT_DIR/chronote-cli-arm64" "$EMBEDDED_CLI_PATH"
        chmod +x "$EMBEDDED_CLI_PATH"
    elif [ "$ARCH_NAME" = "x86_64" ] && [ -f "$CLI_OUT_DIR/chronote-cli-x86_64" ]; then
        cp "$CLI_OUT_DIR/chronote-cli-x86_64" "$EMBEDDED_CLI_PATH"
        chmod +x "$EMBEDDED_CLI_PATH"
    fi
    if [ ! -x "$EMBEDDED_CLI_PATH" ]; then
        echo "Error: Failed to embed chronote-cli into $EMBEDDED_CLI_PATH"
        return 1
    fi

    # Prepare staging directory for DMG
    local STAGING="${STAGING_DIR}_${ARCH_NAME}"
    echo "Preparing DMG contents for $ARCH_NAME..."
    rm -rf "$STAGING"
    mkdir -p "$STAGING"
    cp -R "$APP_PATH" "$STAGING/"
    ln -s /Applications "$STAGING/Applications"
    
    # Create DMG with architecture-specific name
    local DMG_NAME="$DIST_DIR/Chronote-${ARCH_NAME}.dmg"
    echo "Creating DMG for $ARCH_NAME..."
    hdiutil create -volname "$APP_NAME" \
                   -srcfolder "$STAGING" \
                   -ov -format UDZO \
                   "$DMG_NAME"
    
    if [ $? -eq 0 ]; then
        echo "✓ Success! DMG created: $DMG_NAME"
        
        # Cleanup
        rm -rf "$BUILD_PATH"
        rm -rf "$STAGING"
        return 0
    else
        echo "Error: Failed to create DMG for $ARCH_NAME."
        return 1
    fi
}

# Function to build universal binary
build_universal() {
    local BUILD_PATH="${BUILD_DIR}_universal"
    
    echo "==============================================="
    echo "Building Universal Binary (arm64 + x86_64)..."
    echo "==============================================="
    
    # Clean previous build
    rm -rf "$BUILD_PATH"
    
    # Build for both architectures
    xcodebuild -project "$PROJECT_NAME" \
               -scheme "$SCHEME" \
               -configuration Release \
               -derivedDataPath "$BUILD_PATH" \
               -arch arm64 -arch x86_64 \
               ONLY_ACTIVE_ARCH=NO \
               build
    
    if [ $? -ne 0 ]; then
        echo "Error: Universal build failed."
        return 1
    fi
    
    # Locate the built app
    APP_PATH="$BUILD_PATH/Build/Products/Release/$APP_NAME.app"
    
    if [ ! -d "$APP_PATH" ]; then
        echo "Error: App bundle not found at $APP_PATH"
        return 1
    fi
    
    # Verify it's a universal binary
    echo "Verifying universal binary..."
    lipo -info "$APP_PATH/Contents/MacOS/$APP_NAME"
    
    # Embed universal CLI binary inside app bundle resources
    local EMBEDDED_CLI_PATH="$APP_PATH/Contents/Resources/chronote-cli"
    if [ -f "$CLI_OUT_DIR/chronote-cli" ]; then
        cp "$CLI_OUT_DIR/chronote-cli" "$EMBEDDED_CLI_PATH"
        chmod +x "$EMBEDDED_CLI_PATH"
    fi
    if [ ! -x "$EMBEDDED_CLI_PATH" ]; then
        echo "Error: Failed to embed chronote-cli into $EMBEDDED_CLI_PATH"
        return 1
    fi

    # Prepare staging directory for DMG
    local STAGING="${STAGING_DIR}_universal"
    echo "Preparing DMG contents for Universal..."
    rm -rf "$STAGING"
    mkdir -p "$STAGING"
    cp -R "$APP_PATH" "$STAGING/"
    ln -s /Applications "$STAGING/Applications"
    
    # Create DMG
    local DMG_NAME="$DIST_DIR/Chronote-Universal.dmg"
    echo "Creating Universal DMG..."
    hdiutil create -volname "$APP_NAME" \
                   -srcfolder "$STAGING" \
                   -ov -format UDZO \
                   "$DMG_NAME"
    
    if [ $? -eq 0 ]; then
        echo "✓ Success! DMG created: $DMG_NAME"
        
        # Cleanup
        rm -rf "$BUILD_PATH"
        rm -rf "$STAGING"
        return 0
    else
        echo "Error: Failed to create Universal DMG."
        return 1
    fi
}

# Parse arguments
BUILD_ALL=false
for arg in "$@"; do
    case $arg in
        --all)
            BUILD_ALL=true
            shift
            ;;
    esac
done

# Detect current architecture
CURRENT_ARCH=$(uname -m)
if [ "$CURRENT_ARCH" = "arm64" ]; then
    CURRENT_ARCH_NAME="ARM64"
else
    CURRENT_ARCH_NAME="x86_64"
fi

# Main build process
echo "==============================================="
if [ "$BUILD_ALL" = true ]; then
    echo "Starting Multi-Architecture Build Process (ALL)"
else
    echo "Starting Build Process for $CURRENT_ARCH_NAME"
    echo "(use --all to build all architectures)"
fi
echo "==============================================="

# Increment build number first
increment_build_number

# Create dist directory
echo "Creating dist directory..."
mkdir -p "$DIST_DIR"

# Clean old DMG files
echo "Cleaning old DMG files..."
rm -f "$DIST_DIR"/Chronote-*.dmg

echo "Building standalone chronote-cli binaries..."
if [ "$BUILD_ALL" = true ]; then
    ./scripts/build-chronote-cli.sh "$CLI_OUT_DIR"
else
    ./scripts/build-chronote-cli.sh "$CLI_OUT_DIR" "$CURRENT_ARCH"
fi

# Build versions
FAILED=0

if [ "$BUILD_ALL" = true ]; then
    # Build all three versions
    build_universal
    if [ $? -ne 0 ]; then FAILED=1; fi

    build_for_architecture "arm64" "ARM64"
    if [ $? -ne 0 ]; then FAILED=1; fi

    build_for_architecture "x86_64" "x86_64"
    if [ $? -ne 0 ]; then FAILED=1; fi
else
    # Build only current architecture
    build_for_architecture "$CURRENT_ARCH" "$CURRENT_ARCH_NAME"
    if [ $? -ne 0 ]; then FAILED=1; fi
fi

# Final summary
echo ""
echo "==============================================="
echo "Build Summary"
echo "==============================================="

if [ $FAILED -eq 0 ]; then
    echo "✓ All builds completed successfully!"
    echo ""
    echo "Created DMG files:"
    ls -lh "$DIST_DIR"/Chronote-*.dmg
else
    echo "⚠ Some builds failed. Check the output above."
    exit 1
fi
