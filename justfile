# Justfile for Echo Macro Plugin
# https://github.com/casey/just
#
# Usage: just <command>
#   just build      - Build the plugin
#   just package    - Build and create .sdPlugin bundle
#   just zip        - Build, package, and create zip
#   just install    - Build, package, and install to OpenDeck
#   just all        - Build, package, zip, and install
#   just clean      - Clean build artifacts
#   just test       - Run cargo tests

# Default recipe
_default:
    @just --list

# Plugin metadata
plugin_name := "echo-macro"
plugin_uuid := "net.ashurtech.echo-macro"
sdplugin_name := plugin_uuid + ".sdPlugin"
plugin_package := plugin_uuid + ".streamDeckPlugin"

# Directories
build_dir := "build"
plugin_dir := build_dir + "/" + sdplugin_name

# Build the Rust binary
build:
    @echo "Building Echo Macro plugin..."
    cargo build --release

# Create the .sdPlugin bundle directory
package: build
    @echo "Creating .sdPlugin bundle..."
    rm -rf {{plugin_dir}}
    mkdir -p {{plugin_dir}}
    
    # Copy required files
    cp manifest.json {{plugin_dir}}/
    cp property-inspector.html {{plugin_dir}}/
    
    # Copy binary (Linux)
    cp target/release/echo-macro {{plugin_dir}}/
    chmod +x {{plugin_dir}}/echo-macro
    
    @echo "✓ Bundle created: {{plugin_dir}}"

# Create OpenDeck plugin package (.streamDeckPlugin file which is a zip)
zip: package
    @echo "Creating OpenDeck plugin package..."
    cd {{build_dir}} && zip -r {{plugin_package}} {{sdplugin_name}}
    @echo "✓ Plugin package: {{build_dir}}/{{plugin_package}}"

# Install to OpenDeck plugins directory
install: package
    @#!/usr/bin/env bash
    echo "Installing to OpenDeck..."
    
    # Detect platform and set plugin directory
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OPENDECK_DIR="${HOME}/.config/opendeck/plugins"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OPENDECK_DIR="${HOME}/Library/Application Support/opendeck/plugins"
    else
        OPENDECK_DIR="${HOME}/.config/opendeck/plugins"
    fi
    
    mkdir -p "${OPENDECK_DIR}"
    
    # Remove old version
    if [ -d "${OPENDECK_DIR}/{{sdplugin_name}}" ]; then
        rm -rf "${OPENDECK_DIR}/{{sdplugin_name}}"
    fi
    
    # Install new version
    cp -r {{plugin_dir}} "${OPENDECK_DIR}/"
    echo "✓ Installed to: ${OPENDECK_DIR}/{{sdplugin_name}}"
    echo "Note: You may need to restart OpenDeck or click 'Reload Plugins'"

# Build, package, zip, and install
all: zip install

# Clean build artifacts
clean:
    cargo clean
    rm -rf {{build_dir}}
    @echo "Cleaned build artifacts"

# Run tests
test:
    cargo test

# Check code formatting and linting
check:
    cargo fmt -- --check
    cargo clippy -- -D warnings

# Format code
fmt:
    cargo fmt
