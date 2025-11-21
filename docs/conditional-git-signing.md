# Conditional Git Signing for Apple Repositories

## Overview

This solution provides conditional git commit signing based on repository remote domains. It wraps the Apple Code Signing tool (`ac-sign`) to only sign commits for repositories with `apple.com` remotes, while bypassing signing for all other repositories including private GitHub repositories.

## Problem Statement

The `ac-sign` binary is configured globally as the GPG x509 program for git commit signing. This causes all commits across all repositories to be signed, which may not be desired for non-Apple repositories (e.g., personal GitHub projects).

## Solution

A wrapper script intercepts calls to `ac-sign` and:
1. Detects the git repository's remote URL(s)
2. Checks if any remote contains `apple.com`
3. If yes: Calls the original `ac-sign` binary for signing
4. If no: Bypasses signing and allows the commit to proceed unsigned

## Files

- **`script/ac-sign-wrapper.sh`** - The wrapper script that conditionally calls ac-sign
- **`script/install-conditional-signing.sh`** - Installation script
- **`script/uninstall-conditional-signing.sh`** - Uninstallation script

## Installation

### Prerequisites

- The Apple Code Signing tool (`ac-sign`) must be installed at `/usr/local/bin/ac-sign`
- Git must be configured to use `ac-sign` for signing (typically via `gpg.x509.program`)

### Install the Wrapper

```bash
# From the project root directory
sudo script/install-conditional-signing.sh
```

The installation script will:
1. Backup the original `ac-sign` binary to `/usr/local/bin/ac-sign-original`
2. Install the wrapper script as `/usr/local/bin/ac-sign`
3. Make the wrapper executable

### Verify Installation

```bash
# Check that both files exist
ls -l /usr/local/bin/ac-sign*

# Expected output:
# /usr/local/bin/ac-sign          (wrapper script)
# /usr/local/bin/ac-sign-original (original binary)
```

## Usage

Once installed, the wrapper works automatically. No changes to your git workflow are required.

### Behavior

**For Apple repositories** (remotes containing `apple.com`):
- Commits are signed using the original `ac-sign` binary
- Full signing functionality is preserved

**For non-Apple repositories** (GitHub, GitLab, etc.):
- Signing is bypassed
- Commits proceed without signatures
- No errors or warnings are generated

### Testing

Test in an Apple repository:
```bash
cd /path/to/apple/repository
git commit -m "Test commit"
# Should be signed normally
```

Test in a non-Apple repository:
```bash
cd /path/to/github/repository
git commit -m "Test commit"
# Should proceed without signing
```

Verify commit signatures:
```bash
# Check if a commit is signed
git log --show-signature -1
```

## Uninstallation

To restore the original `ac-sign` binary:

```bash
sudo script/uninstall-conditional-signing.sh
```

This will:
1. Remove the wrapper script
2. Restore the original `ac-sign` binary from backup
3. Resume normal signing behavior for all repositories

## Technical Details

### How It Works

1. **Detection**: The wrapper script uses `git remote -v` to list all remote URLs for the current repository
2. **Domain Check**: It searches for `apple.com` in any remote URL using grep
3. **Conditional Execution**:
   - If `apple.com` is found: `exec` the original binary with all arguments
   - If not found: Exit successfully without signing

### Edge Cases Handled

- **No git repository**: Defaults to not signing (safe fallback)
- **Multiple remotes**: Checks all remotes, signs if any contain `apple.com`
- **Git hooks context**: Works correctly when called from git hooks by using `GIT_DIR` environment variable
- **Signing operations**: Properly handles GPG signing flags (`-bsau`, `--sign`)
- **Non-signing operations**: Passes through other operations unchanged

### Security Considerations

- The wrapper preserves full signing functionality for Apple repositories
- No signing keys or credentials are modified or exposed
- The original binary is safely backed up and can be restored at any time
- The wrapper runs with the same permissions as the original binary

## Troubleshooting

### Wrapper not working

Check if the wrapper is installed correctly:
```bash
file /usr/local/bin/ac-sign
# Should show: "Bourne-Again shell script"

file /usr/local/bin/ac-sign-original
# Should show: "Mach-O universal binary"
```

### Commits still being signed in non-Apple repos

Verify the remote URL contains the domain check:
```bash
git remote -v
# Check if any remote contains "apple.com"
```

### Permission errors

Ensure the wrapper is executable:
```bash
sudo chmod +x /usr/local/bin/ac-sign
```

### Restore original behavior

If you encounter any issues, you can always uninstall:
```bash
sudo script/uninstall-conditional-signing.sh
```

## Configuration

The wrapper uses these paths by default:
- **Wrapper location**: `/usr/local/bin/ac-sign`
- **Original binary**: `/usr/local/bin/ac-sign-original`
- **Domain to check**: `apple.com`

To modify the domain check, edit `script/ac-sign-wrapper.sh` and change the grep pattern in the `is_apple_repository()` function.

## Maintenance

### Updating the Wrapper

To update the wrapper script:
```bash
# Edit the wrapper
vim script/ac-sign-wrapper.sh

# Reinstall
sudo script/install-conditional-signing.sh
```

### Backup Considerations

The installation script creates a backup of the original binary. Keep this backup safe:
- Location: `/usr/local/bin/ac-sign-original`
- Purpose: Allows restoration of original functionality
- Important: Do not delete this file while the wrapper is installed

## License

This solution is part of the Chatwoot project and follows the same license terms.