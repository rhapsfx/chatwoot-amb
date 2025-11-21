#!/bin/bash
#
# Uninstallation script for conditional git signing wrapper
#
# This script removes the ac-sign wrapper and restores the original binary.

set -e

AC_SIGN_PATH="/usr/local/bin/ac-sign"
AC_SIGN_BACKUP="/usr/local/bin/ac-sign-original"

echo "=== Conditional Git Signing Wrapper Uninstallation ==="
echo ""

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo"
    echo "Usage: sudo $0"
    exit 1
fi

# Check if backup exists
if [ ! -f "$AC_SIGN_BACKUP" ]; then
    echo "Error: Backup not found at $AC_SIGN_BACKUP"
    echo "The wrapper may not be installed, or the backup was removed."
    exit 1
fi

# Confirm uninstallation
read -p "This will restore the original ac-sign binary. Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# Restore the original ac-sign
echo "Restoring original ac-sign from backup..."
mv "$AC_SIGN_BACKUP" "$AC_SIGN_PATH"
chmod +x "$AC_SIGN_PATH"
echo "✓ Original ac-sign restored"

echo ""
echo "=== Uninstallation Complete ==="
echo ""
echo "The original ac-sign binary has been restored."
echo "All commits will now be signed according to your git configuration."