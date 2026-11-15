# Validate Command

Verify Claude Toolkit installation integrity and functionality.

## Syntax

```bash
./scripts/claude-toolkit.sh validate [options]
```

## Description

The `validate` command performs comprehensive verification of the Claude Toolkit installation to ensure all components are properly installed and functional. It:

1. **Repository Validation**: Verifies git repository state and integrity
2. **Script Validation**: Confirms all required scripts exist and are executable
3. **Symlink Validation**: Checks that symlinks point to correct locations
4. **Functional Validation**: Tests that the installation can perform basic operations

This command is useful for troubleshooting installation issues and verifying system integrity.

## Options

- `--dry-run` - Preview validation without making changes
- `--debug` - Enable debug output
- `--help, -h` - Show help message

## Validation Process

### 1. Repository Validation

Validates the git repository structure and state:

```bash
# Check repository directory exists
test -d ~/.local/share/claude-toolkit/.git

# Verify git repository is in valid state
git -C ~/.local/share/claude-toolkit/ status >/dev/null

# Confirm repository can perform basic operations
git -C ~/.local/share/claude-toolkit/ log -1 >/dev/null
```

### 2. Script Validation

Validates all required scripts:

```bash
# Required scripts must exist and be executable
~/.local/share/claude-toolkit/scripts/claude-toolkit.sh
~/.local/share/claude-toolkit/scripts/claude-code.sh  
~/.local/share/claude-toolkit/scripts/claude-slash.sh
```

### 3. Symlink Validation

Verifies symlinks are properly created and functional:

```bash
# Symlinks should exist and point to correct targets
~/.local/bin/claude-toolkit -> ../share/claude-toolkit/scripts/claude-toolkit.sh
~/.local/bin/claude-code -> ../share/claude-toolkit/scripts/claude-code.sh
~/.local/bin/claude-slash -> ../share/claude-toolkit/scripts/claude-slash.sh
```

## Examples

### Basic Validation

```bash
./scripts/claude-toolkit.sh validate
```

**Successful Output**:
```
[INFO] Validating Claude Toolkit...
[SUCCESS] Claude Toolkit validated, everything looks OK
```

**Failed Validation Output**:
```
[INFO] Validating Claude Toolkit...
[ERROR] Repository at ~/.local/share/claude-toolkit is invalid or corrupted
[ERROR] File is not executable: ~/.local/share/claude-toolkit/scripts/claude-code.sh
[INFO] Please run `./scripts/claude-toolkit.sh reinstall` to fully reinstall it
```

### Debug Validation

```bash
./scripts/claude-toolkit.sh validate --debug
```

**Debug Output**:
```
[INFO] Debug mode enabled
[DEBUG] validate_toolkit
[INFO] Validating Claude Toolkit...
[DEBUG] validate_repository(~/.local/share/claude-toolkit)
[DEBUG] Validating script: ~/.local/share/claude-toolkit/scripts/claude-toolkit.sh
[DEBUG] Validating script: ~/.local/share/claude-toolkit/scripts/claude-code.sh
[DEBUG] Validating script: ~/.local/share/claude-toolkit/scripts/claude-slash.sh
[SUCCESS] Claude Toolkit validated, everything looks OK
```

### Dry-Run Validation

```bash
./scripts/claude-toolkit.sh validate --dry-run
```

Output:
```
dryrun:validate_toolkit
```

## Validation Checks

### Repository Integrity Checks

1. **Directory Structure**:
   - `~/.local/share/claude-toolkit/` exists
   - `.git` directory present and valid
   - Required subdirectories exist (`scripts/`, `slash-commands/`, etc.)

2. **Git Repository State**:
   - Repository is in clean state (no corruption)
   - Can execute basic git operations
   - Repository has valid commit history

3. **File Permissions**:
   - All script files have execute permissions
   - Directory permissions allow read/write access
   - No permission conflicts

### Script Validation Checks

1. **File Existence**:
   - `claude-toolkit.sh` exists
   - `claude-code.sh` exists  
   - `claude-slash.sh` exists
   - `library.sh` exists

2. **Executability**:
   - All scripts have execute permission (`chmod +x`)
   - Scripts can be executed without errors
   - No syntax errors in shell scripts

3. **Functionality**:
   - Scripts can display help information
   - Basic operations work correctly
   - Dependencies are satisfied

### Symlink Validation Checks

1. **Symlink Existence**:
   - `~/.local/bin/claude-toolkit` exists
   - `~/.local/bin/claude-code` exists
   - `~/.local/bin/claude-slash` exists

2. **Target Validation**:
   - Symlinks point to correct script locations
   - Target files exist and are executable
   - No broken symlinks

3. **PATH Integration**:
   - `~/.local/bin` is in user's PATH
   - Commands are accessible from shell
   - No conflicts with system commands

## Common Validation Failures

### Repository Issues

**Missing Repository**:
```bash
[ERROR] Not a git repository: ~/.local/share/claude-toolkit
```
**Solution**: Run `./scripts/claude-toolkit.sh install`

**Corrupted Repository**:
```bash
[ERROR] Repository is in invalid state: ~/.local/share/claude-toolkit
```
**Solution**: Run `./scripts/claude-toolkit.sh reinstall`

### Script Issues

**Missing Scripts**:
```bash
[ERROR] File not found: ~/.local/share/claude-toolkit/scripts/claude-code.sh
```
**Solution**: Run `./scripts/claude-toolkit.sh reinstall`

**Permission Issues**:
```bash
[ERROR] File is not executable: ~/.local/share/claude-toolkit/scripts/claude-toolkit.sh
```
**Solution**: Fix permissions or reinstall:
```bash
chmod +x ~/.local/share/claude-toolkit/scripts/*.sh
```

### Symlink Issues

**Missing Symlinks**:
```bash
# Check if symlinks exist
ls -la ~/.local/bin/claude-*
```
**Solution**: Recreate symlinks or reinstall:
```bash
./scripts/claude-toolkit.sh reinstall
```

**Broken Symlinks**:
```bash
# Check symlink targets
readlink ~/.local/bin/claude-toolkit
```
**Solution**: Remove broken symlinks and reinstall:
```bash
rm ~/.local/bin/claude-*
./scripts/claude-toolkit.sh install
```

## Integration with Other Commands

### Automatic Validation

Many commands automatically run validation:

```bash
# Install command validates after installation
./scripts/claude-toolkit.sh install
# → Automatically runs validate at the end

# Update command validates before and after update  
./scripts/claude-toolkit.sh update
# → Validates current installation
# → Performs update
# → Validates updated installation
```

### Manual Validation

Use validate command for troubleshooting:

```bash
# Check installation health
./scripts/claude-toolkit.sh validate

# If validation fails, get more details
./scripts/claude-toolkit.sh validate --debug

# After making manual fixes, re-validate
./scripts/claude-toolkit.sh validate
```

## Validation in Different Scenarios

### Development Environment

```bash
# Validate after making changes to scripts
./scripts/claude-toolkit.sh validate --debug

# Validate before committing changes
./scripts/claude-toolkit.sh validate && git commit -m "Update scripts"
```

### Production Environment

```bash
# Regular health checks
./scripts/claude-toolkit.sh validate

# CI/CD validation
./scripts/claude-toolkit.sh validate || exit 1
```

### Troubleshooting Environment

```bash
# Comprehensive validation with full debugging
./scripts/claude-toolkit.sh validate --debug > validation-output.log 2>&1

# Review validation results
cat validation-output.log
```

## Performance

### Validation Speed

Validation is designed to be fast:

- **Local Operations**: All checks are local file system operations
- **Minimal Git Operations**: Only basic git status checks
- **Cached Results**: Some validation results may be cached
- **Early Exit**: Stops on first critical failure for speed

### Resource Usage

- **Low Memory**: Minimal memory footprint
- **Low CPU**: Simple file and directory checks
- **No Network**: All validation is local (no remote operations)

## Exit Codes

The validate command uses standard exit codes:

- **0**: Validation successful, all checks passed
- **1**: Validation failed, issues found
- **2**: Invalid arguments or usage error

```bash
# Use in scripts
if ./scripts/claude-toolkit.sh validate; then
    echo "Toolkit is healthy"
else
    echo "Toolkit needs attention"
    ./scripts/claude-toolkit.sh validate --debug
fi
```

## Troubleshooting

### Common Issues

1. **Repository corruption**:
   ```bash
   # Validate to identify issue
   ./scripts/claude-toolkit.sh validate --debug
   # Reinstall if corrupted
   ./scripts/claude-toolkit.sh reinstall
   ```

2. **Permission problems**:
   ```bash
   # Check file permissions
   ls -la ~/.local/share/claude-toolkit/scripts/
   # Fix permissions
   chmod +x ~/.local/share/claude-toolkit/scripts/*.sh
   ```

3. **Symlink issues**:
   ```bash
   # Check symlinks
   ls -la ~/.local/bin/claude-*
   # Recreate if broken
   ./scripts/claude-toolkit.sh reinstall
   ```

4. **PATH configuration**:
   ```bash
   # Check if commands are accessible
   which claude-toolkit
   # Add to PATH if needed
   export PATH="$HOME/.local/bin:$PATH"
   ```

### Recovery Procedures

When validation fails:

1. **Identify Issue**: Run with `--debug` to see detailed error information
2. **Attempt Repair**: Try specific fixes based on error messages
3. **Reinstall if Needed**: Use `reinstall` command for comprehensive recovery
4. **Verify Fix**: Run validate again to confirm resolution

## Related Commands

- **[`install`](install.md)** - Initial toolkit installation (includes validation)
- **[`update`](update.md)** - Update toolkit (validates before and after)
- **[`reinstall`](reinstall.md)** - Force complete reinstallation
- **[`uninstall`](uninstall.md)** - Remove installation