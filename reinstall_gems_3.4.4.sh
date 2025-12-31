#!/bin/bash
# Reinstall gems for Ruby 3.4.4

echo "=========================================="
echo "Reinstalling Gems for Ruby 3.4.4"
echo "=========================================="
echo ""

# Verify Ruby version
echo "Current Ruby version:"
ruby --version
echo ""

# Install bundler for Ruby 3.4.4
echo "Installing bundler..."
gem install bundler
echo ""

# Clean old bundle
echo "Cleaning old bundle..."
rm -rf .bundle vendor/bundle
echo ""

# Install all gems
echo "Installing gems (this may take several minutes)..."
bundle install
echo ""

# Verify Rails is available
echo "Verifying Rails installation..."
if bundle exec rails --version > /dev/null 2>&1; then
    echo "✓ Rails installed successfully:"
    bundle exec rails --version
else
    echo "✗ Rails installation failed"
    exit 1
fi
echo ""

echo "=========================================="
echo "Gem Installation Complete!"
echo "=========================================="
echo ""
echo "You can now start the dev server:"
echo "  ./script/dev-server.sh start"
echo ""
