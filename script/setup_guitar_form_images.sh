#!/bin/bash
# Script to copy guitar images from Acoustic House Bot to the form image directory

set -e

echo "🎸 Setting up Guitar Form Images"
echo "================================="

# Create the target directory
TARGET_DIR="tmp/guitar_form_images"
mkdir -p "$TARGET_DIR"
echo "✅ Created directory: $TARGET_DIR"

# Source directory
SOURCE_DIR="_apple/Acoustic-House-Bot-origin/acoustichouse/images"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ Error: Source directory not found: $SOURCE_DIR"
    exit 1
fi

echo ""
echo "📋 Copying images..."

# Copy Gibson Les Paul
if [ -f "$SOURCE_DIR/GibsonLesPaul2.jpg" ]; then
    cp "$SOURCE_DIR/GibsonLesPaul2.jpg" "$TARGET_DIR/gibson_les_paul.png"
    echo "✅ gibson_les_paul.png (from GibsonLesPaul2.jpg)"
else
    echo "⚠️  Gibson image not found"
fi

# Copy Martin Dreadnought
if [ -f "$SOURCE_DIR/MartinDC28EDreadnought2.jpg" ]; then
    cp "$SOURCE_DIR/MartinDC28EDreadnought2.jpg" "$TARGET_DIR/martin_dreadnought.png"
    echo "✅ martin_dreadnought.png (from MartinDC28EDreadnought2.jpg)"
else
    echo "⚠️  Martin image not found"
fi

# Copy Paul Reed Smith
if [ -f "$SOURCE_DIR/PRS.png" ]; then
    cp "$SOURCE_DIR/PRS.png" "$TARGET_DIR/paul_reed_smith.png"
    echo "✅ paul_reed_smith.png (from PRS.png)"
else
    echo "⚠️  PRS image not found"
fi

# Copy header image (using pick.png as guitar-related header)
if [ -f "$SOURCE_DIR/pick.png" ]; then
    cp "$SOURCE_DIR/pick.png" "$TARGET_DIR/guitar_collection_header.png"
    echo "✅ guitar_collection_header.png (from pick.png)"
elif [ -f "$SOURCE_DIR/ah_wide.png" ]; then
    cp "$SOURCE_DIR/ah_wide.png" "$TARGET_DIR/guitar_collection_header.png"
    echo "✅ guitar_collection_header.png (from ah_wide.png)"
else
    echo "⚠️  Header image not found"
fi

echo ""
echo "================================="
echo "✨ Image setup complete!"
echo ""
echo "📁 Images are now in: $TARGET_DIR"
echo ""
ls -lh "$TARGET_DIR"
echo ""
echo "🚀 Next step: Run the form creation script"
echo "   rails runner script/create_guitar_info_form_template.rb --account-id <ID> --inbox-id <ID>"
