#!/bin/bash
#
# Installation script for conditional git signing wrapper
#
# This script installs the ac-sign wrapper that conditionally signs
# git commits based on repository remote domain.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER_SCRIPT="$SCRIPT_DIR/ac-sign-wrapper.sh"
AC_SIGN_PATH="/usr/local/bin/ac-sign"
AC_SIGN_BACKUP="/usr/local/bin/ac-sign-original"

echo "=== Conditional Git Signing Wrapper Installation ==="
echo ""

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo"
    echo "Usage: sudo $0"
    exit 1
fi

# Check if wrapper script exists
if [ ! -f "$WRAPPER_SCRIPT" ]; then
    echo "Error: Wrapper script not found at $WRAPPER_SCRIPT"
    exit 1
fi

# Check if ac-sign exists
if [ ! -f "$AC_SIGN_PATH" ]; then
    echo "Error: ac-sign not found at $AC_SIGN_PATH"
    echo "The Apple Code Signing tool doesn't appear to be installed."
    exit 1
fi

# Check if already installed
if [ -f "$AC_SIGN_BACKUP" ]; then
    echo "Warning: Backup already exists at $AC_SIGN_BACKUP"
    echo "It appears the wrapper may already be installed."
    read -p "Do you want to reinstall? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
else
    # Backup the original ac-sign
    echo "Backing up original ac-sign to $AC_SIGN_BACKUP..."
    cp "$AC_SIGN_PATH" "$AC_SIGN_BACKUP"
    echo "✓ Backup created"
fi

# Install the wrapper
echo "Installing wrapper script..."
cp "$WRAPPER_SCRIPT" "$AC_SIGN_PATH"
chmod +x "$AC_SIGN_PATH"
echo "✓ Wrapper installed"

# Verify installation
if [ -x "$AC_SIGN_PATH" ] && [ -x "$AC_SIGN_BACKUP" ]; then
    echo ""
    echo "=== Installation Complete ==="
    echo ""
    echo "The conditional signing wrapper is now active."
    echo ""
    echo "Behavior:"
    echo "  • Apple repositories (*.apple.com): Commits will be signed"
    echo "  • Other repositories (GitHub, etc.): Signing will be bypassed"
    echo ""
    echo "Files:"
    echo "  • Wrapper: $AC_SIGN_PATH"
    echo "  • Original: $AC_SIGN_BACKUP"
    echo ""
    echo "To uninstall, run: sudo $SCRIPT_DIR/uninstall-conditional-signing.sh"
else
    echo ""
    echo "Error: Installation verification failed"
    exit 1
fi