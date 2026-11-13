# Conditional Git Signing for Apple Repositories

## Overview

This solution provides conditional git commit signing based on repository remote domains. It wraps the Apple Code Signing tool (`ac-sign`) to only sign commits for repositories with `apple.com` remotes, while bypassing signing for all other repositories including private GitHub repositories.

## Problem Statement

The `ac-sign` binary is configured globally as the GPG x509 program for git commit signing. This causes all commits across all repositories to attempt signing, which may not be desired for non-Apple repositories (e.g., personal GitHub projects).

## Solution

The solution uses a two-part approach:

1. **Wrapper Script**: Intercepts calls to `ac-sign` and detects repository domain
2. **Local Git Configuration**: Disables commit signing for non-Apple repositories

### How It Works

For **Apple repositories** (remotes containing `apple.com`):
- Keep global `commit.gpgsign=true` setting
- Wrapper calls original `ac-sign` binary for full signing functionality

For **non-Apple repositories** (GitHub, GitLab, etc.):
- Set local `commit.gpgsign=false` in the repository
- Commits proceed without signing
- No Touch ID prompts or signing operations

## Files

- **`script/ac-sign-wrapper.sh`** - The wrapper script that conditionally calls ac-sign
- **`script/install-conditional-signing.sh`** - Installation script
- **`script/uninstall-conditional-signing.sh`** - Uninstallation script
- **`script/setup-repo-signing.sh`** - Helper script to configure repositories

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

### Configure Your Repositories

After installing the wrapper, you need to configure each non-Apple repository:

```bash
# For each non-Apple repository (GitHub, GitLab, etc.)
cd /path/to/your/github/repo
git config --local commit.gpgsign false
```

For Apple repositories, no configuration is needed - they will use the global `commit.gpgsign=true` setting.

### Verify Installation

```bash
# Check that both files exist
ls -l /usr/local/bin/ac-sign*

# Expected output:
# /usr/local/bin/ac-sign          (wrapper script)
# /usr/local/bin/ac-sign-original (original binary)

# Check global git config
git config --global commit.gpgsign
# Should show: true

# Check local config in a non-Apple repo
cd /path/to/github/repo
git config --local commit.gpgsign
# Should show: false
```

## Usage

Once installed and configured, the system works automatically. No changes to your git workflow are required.

### Behavior

**For Apple repositories** (remotes containing `apple.com`):
- Commits are signed using the original `ac-sign` binary
- Touch ID prompts appear as normal
- Full signing functionality is preserved

**For non-Apple repositories** (GitHub, GitLab, etc.):
- Signing is disabled via local git config
- Commits proceed without signatures
- No Touch ID prompts
- No signing operations

### Testing

Test in an Apple repository:
```bash
cd /path/to/apple/repository
git commit -m "Test commit"
# Should prompt for Touch ID and be signed

git log --show-signature -1
# Should show signature information
```

Test in a non-Apple repository:
```bash
cd /path/to/github/repository

# First, disable signing for this repo
git config --local commit.gpgsign false

git commit -m "Test commit"
# Should proceed without Touch ID prompt

git log --show-signature -1
# Should NOT show signature information
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

You may also want to re-enable signing in repositories where you disabled it:

```bash
cd /path/to/repo
git config --local --unset commit.gpgsign
```

## Technical Details

### How the Wrapper Works

1. **Detection**: The wrapper script uses `git remote -v` to list all remote URLs for the current repository
2. **Domain Check**: It searches for `apple.com` in any remote URL using grep
3. **Conditional Execution**:
   - If `apple.com` is found: `exec` the original binary with all arguments
   - If not found: Exit successfully (though signing should be disabled via git config)

### Why Two-Part Approach?

The wrapper alone cannot prevent git from calling the signing program because `commit.gpgsign=true` is set globally. When git tries to sign and the wrapper returns without output, git fails with "gpg failed to sign the data".

The solution is to:
1. Keep the wrapper for Apple repository detection and logging
2. Use local git config to disable signing for non-Apple repositories

This approach is:
- **Reliable**: Git doesn't attempt signing when `commit.gpgsign=false`
- **Explicit**: Each repository's signing behavior is clear
- **Maintainable**: Easy to see which repos have signing enabled/disabled

### Debug Logging

The wrapper includes optional debug logging. To enable:

```bash
# Edit the wrapper to uncomment the DEBUG_LOG line
sudo nano /usr/local/bin/ac-sign

# Or use sed
sudo sed -i '' 's|# DEBUG_LOG="/tmp/ac-sign-wrapper.log"|DEBUG_LOG="/tmp/ac-sign-wrapper.log"|' /usr/local/bin/ac-sign

# View logs
tail -f /tmp/ac-sign-wrapper.log
```

### Edge Cases Handled

- **No git repository**: Defaults to not signing (safe fallback)
- **Multiple remotes**: Checks all remotes, signs if any contain `apple.com`
- **Git hooks context**: Works correctly when called from git hooks by using `GIT_DIR` environment variable
- **Signing operations**: Properly handles GPG signing flags (`-bsau`, `--sign`)
- **Non-signing operations**: Passes through other operations (like `--version`) unchanged

### Security Considerations

- The wrapper preserves full signing functionality for Apple repositories
- No signing keys or credentials are modified or exposed
- The original binary is safely backed up and can be restored at any time
- The wrapper runs with the same permissions as the original binary
- Local git config changes are explicit and reversible

## Troubleshooting

### Still getting Touch ID prompts in non-Apple repos

Check if signing is disabled locally:
```bash
git config --local commit.gpgsign
# Should show: false
```

If not set, disable it:
```bash
git config --local commit.gpgsign false
```

### Wrapper not working

Check if the wrapper is installed correctly:
```bash
file /usr/local/bin/ac-sign
# Should show: "Bourne-Again shell script"

file /usr/local/bin/ac-sign-original
# Should show: "Mach-O universal binary"
```

### Commits failing with "gpg failed to sign"

This means signing is still enabled. Disable it locally:
```bash
git config --local commit.gpgsign false
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

## Automation

### Automatic Repository Configuration

You can create a script to automatically configure all your non-Apple repositories:

```bash
#!/bin/bash
# Disable signing for all non-Apple repositories

for repo in ~/Projects/*/.git; do
    repo_dir=$(dirname "$repo")
    cd "$repo_dir"
    
    # Check if any remote contains apple.com
    if ! git remote -v | grep -q "apple\.com"; then
        echo "Disabling signing for: $repo_dir"
        git config --local commit.gpgsign false
    fi
done
```

### Git Template

You can set up a git template to automatically configure new repositories:

```bash
# Create template directory
mkdir -p ~/.git-templates/hooks

# Create post-clone hook
cat > ~/.git-templates/hooks/post-checkout << 'EOF'
#!/bin/bash
# Disable signing for non-Apple repositories

if ! git remote -v | grep -q "apple\.com"; then
    git config --local commit.gpgsign false
fi
EOF

chmod +x ~/.git-templates/hooks/post-checkout

# Configure git to use the template
git config --global init.templateDir ~/.git-templates
```

## Configuration

The wrapper uses these paths by default:
- **Wrapper location**: `/usr/local/bin/ac-sign`
- **Original binary**: `/usr/local/bin/ac-sign-original`
- **Domain to check**: `apple.com`
- **Debug log**: `/tmp/ac-sign-wrapper.log` (when enabled)

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

## Best Practices

1. **Always configure new repositories**: When cloning or creating a new non-Apple repository, remember to run:
   ```bash
   git config --local commit.gpgsign false
   ```

2. **Document in README**: Add a note in your project README about the signing configuration

3. **Team coordination**: If working in a team, ensure all team members understand the signing setup

4. **Regular verification**: Periodically check your repositories' signing configuration:
   ```bash
   git config --local commit.gpgsign
   ```

## License

This solution is part of the Chatwoot project and follows the same license terms.