# Update Command

Update Claude Toolkit from remote repository while preserving configuration.

## Syntax

```bash
./scripts/claude-toolkit.sh update [options]
```

## Description

The `update` command pulls the latest changes from the remote repository and validates the updated installation. It:

1. **Validates Current Installation**: Ensures existing installation is in good state
2. **Performs Git Pull**: Downloads latest changes from remote repository  
3. **Re-validates Installation**: Confirms updated installation works correctly
4. **Executes Updated Script**: Runs validation with the newly updated script

This command preserves all existing configuration while updating the toolkit codebase.

## Options

- `--https` - Use HTTPS git URLs instead of SSH
- `--dry-run` - Preview update without making changes
- `--debug` - Enable debug output
- `--help, -h` - Show help message

## Update Process

### 1. Pre-Update Validation

Before updating, the command validates the current installation:

```bash
# Checks repository integrity
validate_repository ~/.local/share/claude-toolkit/
# → Verifies .git directory exists
# → Confirms git repository is in valid state  
# → Validates all required scripts exist and are executable
```

### 2. Repository Update

Pulls latest changes from remote:

```bash
git -C ~/.local/share/claude-toolkit/ pull
```

### 3. Post-Update Validation

After updating, validates the new installation by executing the updated script:

```bash
exec ~/.local/share/claude-toolkit/scripts/claude-toolkit.sh validate
```

This ensures that any changes to validation logic in the update are properly applied.

## Examples

### Basic Update

```bash
./scripts/claude-toolkit.sh update
```

Output:
```
[INFO] Updating Claude Toolkit...
[INFO] Validating Claude Toolkit...
[SUCCESS] Claude Toolkit validated, everything looks OK
remote: Enumerating objects: 15, done.
remote: Counting objects: 100% (15/15), done.
remote: Compressing objects: 100% (8/8), done.
remote: Total 9 (delta 6), reused 4 (delta 1), pack-reused 0
Unpacking objects: 100% (9/9), 2.31 KiB | 2.31 MiB/s, done.
From github.pie.apple.com:AI-for-Devs-Community/claude-toolkit
   b7b97df..89a4c21  main       -> origin/main
Updating b7b97df..89a4c21
Fast-forward
 scripts/claude-code.sh | 10 +++++-----
 1 file changed, 5 insertions(+), 5 deletions(-)
[SUCCESS] Claude Toolkit updated
[INFO] Validating Claude Toolkit...
[SUCCESS] Claude Toolkit validated, everything looks OK
```

### HTTPS Update

When SSH access is not available:

```bash
./scripts/claude-toolkit.sh update --https
```

This ensures git operations use HTTPS URLs even if the repository was originally cloned with SSH.

### Development Update

```bash
# Preview update without making changes
./scripts/claude-toolkit.sh update --dry-run
# Output: dryrun:update_toolkit(git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git)

# Update with detailed debugging
./scripts/claude-toolkit.sh update --debug
```

## Repository State Handling

### Valid Repository

If the current installation is valid:

```bash
[INFO] Updating Claude Toolkit...
[INFO] Validating Claude Toolkit...
[SUCCESS] Claude Toolkit validated, everything looks OK
# ... performs git pull ...
[SUCCESS] Claude Toolkit updated
```

### Corrupted Repository

If the current installation is corrupted or invalid:

```bash
[INFO] Updating Claude Toolkit...
[ERROR] Repository at ~/.local/share/claude-toolkit is invalid or corrupted
[ERROR] Not a git repository: ~/.local/share/claude-toolkit
[INFO] Reinstalling Claude Toolkit...
# ... triggers automatic reinstallation ...
```

### Missing Installation

If no installation exists:

```bash
[INFO] Updating Claude Toolkit...
[ERROR] Repository at ~/.local/share/claude-toolkit is invalid or corrupted
[ERROR] Not a git repository: ~/.local/share/claude-toolkit  
[INFO] Reinstalling Claude Toolkit...
# ... triggers automatic installation ...
```

## Automatic Recovery

The update command includes automatic recovery mechanisms:

### Corrupted Repository Recovery

If the repository is corrupted, update automatically triggers reinstallation:

1. **Backup Current Script**: Copies current script to cache directory
2. **Clean Installation**: Performs fresh installation from remote
3. **Preservation**: Maintains all existing shell configuration

### Network Failure Recovery

If git pull fails due to network issues:

```bash
[ERROR] fatal: unable to access 'git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git/': 
[ERROR] Could not resolve hostname github.pie.apple.com: nodename nor servname provided
```

The update fails cleanly without corrupting the existing installation.

## Update Validation

After each update, the toolkit validates itself:

1. **Repository Structure**: Verifies all required files exist
2. **Script Executability**: Confirms scripts have proper permissions
3. **Git Repository State**: Ensures repository is in good state
4. **Functional Validation**: Tests that scripts can execute properly

## Preserving Configuration

Updates preserve all user configuration:

- **Shell Integration**: Existing PATH and environment configuration maintained
- **Symlinks**: Existing symlinks remain functional
- **User Settings**: Any customization in shell RC files preserved

## Update Frequency

### Recommended Update Schedule

```bash
# Check for updates weekly
./scripts/claude-toolkit.sh update

# Or integrate into development workflow
alias toolkit-update='cd ~/toolkit-repo && git pull && ./scripts/claude-toolkit.sh update'
```

### Automated Updates

For team environments:

```bash
#!/bin/bash
# weekly-toolkit-update.sh
cd /path/to/toolkit
git fetch origin
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ $LOCAL != $REMOTE ]; then
    echo "Updates available, updating toolkit..."
    ./scripts/claude-toolkit.sh update
else
    echo "Toolkit is up to date"
fi
```

## Integration Points

### With Other Components

After toolkit updates, other components continue to work:

```bash
# Toolkit update doesn't affect Claude Code installations
./scripts/claude-toolkit.sh update

# Claude Code remains functional
claude --version

# Slash commands remain available  
claude-slash list
```

### Development Workflow Integration

```bash
# Update toolkit and validate all components
./scripts/claude-toolkit.sh update
./scripts/claude-code.sh list --mode installed
./scripts/claude-slash.sh list
```

## Error Handling

### Git Pull Failures

Common git pull issues and resolutions:

```bash
# Merge conflicts (rare, but possible)
[ERROR] error: Your local changes to the following files would be overwritten by merge:
[ERROR]   scripts/claude-toolkit.sh
# Resolution: Automatic reinstallation triggered

# Network connectivity issues
[ERROR] fatal: unable to access 'https://github.pie.apple.com/...': 
[ERROR] Failed to connect to github.pie.apple.com port 443: Connection timed out
# Resolution: Check VPN connection, retry later

# Authentication issues  
[ERROR] remote: Invalid username or password.
# Resolution: Check SSH keys or use --https with token
```

### Repository Corruption

If repository becomes corrupted:

```bash
[ERROR] Repository at ~/.local/share/claude-toolkit is invalid or corrupted
[ERROR] fatal: not a git repository (or any of the parent directories): .git
[INFO] Reinstalling Claude Toolkit...
```

The update command automatically detects corruption and triggers reinstallation.

## Performance Considerations

### Network Optimization

Updates are optimized for performance:

- **Incremental Updates**: Only downloads changed files
- **Efficient Git Operations**: Uses git's built-in optimization
- **Minimal Bandwidth**: Only necessary changes downloaded

### Local Caching

The toolkit uses caching for efficient operations:

- **Repository Cache**: Maintains local git repository
- **Script Cache**: Caches scripts during reinstallation
- **Update Validation**: Minimal validation overhead

## Troubleshooting

### Common Update Issues

1. **Permission denied during git pull**
   ```bash
   # Check repository ownership
   ls -la ~/.local/share/claude-toolkit/
   # Fix ownership if needed
   chown -R $USER:$USER ~/.local/share/claude-toolkit/
   ```

2. **Network connectivity issues**
   ```bash
   # Test connectivity
   ping github.pie.apple.com
   # Check VPN status
   # Try HTTPS: ./scripts/claude-toolkit.sh update --https
   ```

3. **Git repository corruption**
   ```bash
   # Let update handle automatically, or force reinstall
   ./scripts/claude-toolkit.sh reinstall
   ```

4. **Update validation failures**
   ```bash
   # Run manual validation
   ./scripts/claude-toolkit.sh validate
   # Check debug output
   ./scripts/claude-toolkit.sh update --debug
   ```

### Debug Output

Enable detailed debugging for troubleshooting:

```bash
./scripts/claude-toolkit.sh update --debug
```

This shows:
- Repository validation steps
- Git operation details  
- Validation results
- Error details if any

## Related Commands

- **[`install`](install.md)** - Initial toolkit installation
- **[`validate`](validate.md)** - Verify installation integrity
- **[`reinstall`](reinstall.md)** - Force complete reinstallation
- **[`uninstall`](uninstall.md)** - Remove installation
