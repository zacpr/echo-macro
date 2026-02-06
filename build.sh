#!/bin/bash
#
# Echo Macro Plugin Build Script
# 
# This script:
# 1. Compiles the Rust binary in release mode
# 2. Creates the .sdPlugin bundle directory
# 3. Copies all necessary files
# 4. Optionally creates a distributable zip (for store submission or sharing)
#

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Plugin configuration
PLUGIN_NAME="echo-macro"
PLUGIN_UUID="net.ashurtech.echo-macro"
SDPLUGIN_NAME="${PLUGIN_UUID}.sdPlugin"
PLUGIN_PACKAGE="${PLUGIN_UUID}.streamDeckPlugin"

# Build directory
BUILD_DIR="build"
PLUGIN_DIR="${BUILD_DIR}/${SDPLUGIN_NAME}"

echo -e "${GREEN}=== Echo Macro Plugin Builder ===${NC}"
echo ""

# Step 1: Build the Rust binary
echo -e "${YELLOW}Step 1: Building Rust binary...${NC}"
cargo build --release
if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Build successful${NC}"
echo ""

# Step 2: Create the .sdPlugin directory
echo -e "${YELLOW}Step 2: Creating .sdPlugin bundle...${NC}"
rm -rf "${PLUGIN_DIR}"
mkdir -p "${PLUGIN_DIR}"

# Step 3: Copy required files
echo -e "${YELLOW}Step 3: Copying plugin files...${NC}"

# Main manifest (required)
cp manifest.json "${PLUGIN_DIR}/"
echo "  ✓ manifest.json"

# Property Inspector HTML (required for configuration UI)
cp property-inspector.html "${PLUGIN_DIR}/"
echo "  ✓ property-inspector.html"

# Compiled binary - detect platform
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="linux"
    BINARY_NAME="echo-macro"
    cp "target/release/${BINARY_NAME}" "${PLUGIN_DIR}/"
    chmod +x "${PLUGIN_DIR}/${BINARY_NAME}"
    echo "  ✓ ${BINARY_NAME} (Linux x64)"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
    BINARY_NAME="echo-macro"
    cp "target/release/${BINARY_NAME}" "${PLUGIN_DIR}/"
    chmod +x "${PLUGIN_DIR}/${BINARY_NAME}"
    echo "  ✓ ${BINARY_NAME} (macOS)"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    PLATFORM="windows"
    BINARY_NAME="echo-macro.exe"
    cp "target/release/${BINARY_NAME}" "${PLUGIN_DIR}/"
    echo "  ✓ ${BINARY_NAME} (Windows)"
else
    echo -e "${YELLOW}  ⚠ Unknown platform: $OSTYPE, assuming Linux${NC}"
    PLATFORM="linux"
    BINARY_NAME="echo-macro"
    cp "target/release/${BINARY_NAME}" "${PLUGIN_DIR}/"
    chmod +x "${PLUGIN_DIR}/${BINARY_NAME}"
    echo "  ✓ ${BINARY_NAME}"
fi

# Optional: Icons (if they exist)
if [ -d "icons" ]; then
    cp -r icons "${PLUGIN_DIR}/"
    echo "  ✓ icons/"
fi
# Copy icon files from root directory
for ext in png svg; do
    if [ -f "icon.${ext}" ]; then
        cp "icon.${ext}" "${PLUGIN_DIR}/"
        echo "  ✓ icon.${ext}"
    fi
done

# Optional: README
if [ -f "README.md" ]; then
    cp README.md "${PLUGIN_DIR}/"
    echo "  ✓ README.md"
fi

echo ""
echo -e "${GREEN}✓ Plugin bundle created at: ${PLUGIN_DIR}${NC}"
echo ""

# Step 4: Create OpenDeck plugin package (optional)
# OpenDeck expects a .streamDeckPlugin file which is actually a zip
# containing the .sdPlugin folder with all plugin files inside
if [ "$1" == "--zip" ] || [ "$1" == "-z" ] || [ "$2" == "--zip" ] || [ "$2" == "-z" ]; then
    echo -e "${YELLOW}Step 4: Creating OpenDeck plugin package...${NC}"
    
    # Remove old package if exists
    rm -f "${BUILD_DIR}/${PLUGIN_PACKAGE}"
    
    # Create zip with the .sdPlugin folder inside (OpenDeck expects this structure)
    # The file should have .streamDeckPlugin extension, not .zip
    cd "${BUILD_DIR}"
    zip -r "${PLUGIN_PACKAGE}" "${SDPLUGIN_NAME}"
    cd ..
    
    echo -e "${GREEN}✓ Plugin package: ${BUILD_DIR}/${PLUGIN_PACKAGE}${NC}"
    echo ""
    echo "To install in OpenDeck:"
    echo "  1. Open OpenDeck settings"
    echo "  2. Go to Plugins section"
    echo "  3. Click 'Install from File' or drag the .streamDeckPlugin file into OpenDeck"
    echo "  4. Select: ${BUILD_DIR}/${PLUGIN_PACKAGE}"
    echo ""
fi

# Step 5: Install to OpenDeck directly (optional)
if [ "$1" == "--install" ] || [ "$1" == "-i" ] || [ "$2" == "--install" ] || [ "$2" == "-i" ]; then
    echo -e "${YELLOW}Step 5: Installing to OpenDeck...${NC}"
    
    # Detect OpenDeck plugins directory
    # Check for Flatpak installation first
    if [ -d "${HOME}/.var/app/me.amankhanna.opendeck/config/opendeck/plugins" ]; then
        OPENDECK_DIR="${HOME}/.var/app/me.amankhanna.opendeck/config/opendeck/plugins"
        echo "  Detected Flatpak installation"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OPENDECK_DIR="${HOME}/.config/opendeck/plugins"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OPENDECK_DIR="${HOME}/Library/Application Support/opendeck/plugins"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
        OPENDECK_DIR="${APPDATA}/opendeck/plugins"
    else
        OPENDECK_DIR="${HOME}/.config/opendeck/plugins"
    fi
    
    # Create directory if it doesn't exist
    mkdir -p "${OPENDECK_DIR}"
    
    # Remove old version if exists
    if [ -d "${OPENDECK_DIR}/${SDPLUGIN_NAME}" ]; then
        echo "  Removing old version..."
        rm -rf "${OPENDECK_DIR}/${SDPLUGIN_NAME}"
    fi
    
    # Copy new version
    cp -r "${PLUGIN_DIR}" "${OPENDECK_DIR}/"
    echo -e "${GREEN}✓ Installed to: ${OPENDECK_DIR}/${SDPLUGIN_NAME}${NC}"
    echo ""
    echo -e "${YELLOW}Note: You may need to restart OpenDeck or click 'Reload Plugins'${NC}"
fi

echo ""
echo -e "${GREEN}=== Build Complete ===${NC}"
echo ""
echo "Plugin location: ${PLUGIN_DIR}"
echo ""
echo "Usage:"
echo "  ./build.sh           # Just build"
echo "  ./build.sh --zip     # Build + create zip for OpenDeck"
echo "  ./build.sh --install # Build + install directly"
echo "  ./build.sh -i -z     # Build + install + create zip"
echo ""
echo "To install manually:"
echo "  cp -r ${PLUGIN_DIR} ~/.config/opendeck/plugins/"
echo ""
echo "Or install from zip in OpenDeck:"
echo "  ${BUILD_DIR}/${PLUGIN_PACKAGE}"
