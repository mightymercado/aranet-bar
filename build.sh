#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Building Aranet Bar..."
swift build -c release 2>&1

APP_DIR="build/AranetBar.app"
mkdir -p "$APP_DIR/Contents/MacOS"

cp .build/release/AranetBar "$APP_DIR/Contents/MacOS/AranetBar"

echo ""
echo "Build complete: $APP_DIR"
echo ""
echo "To run:     open $APP_DIR"
echo "To install: cp -R $APP_DIR /Applications/"
