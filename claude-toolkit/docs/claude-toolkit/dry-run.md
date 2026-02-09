# Dry-Run Mode

Preview toolkit operations without making any changes to the system.

## Overview

Dry-run mode allows you to preview what any toolkit command would do without actually executing the operations. This is useful for:

- **Verifying Operations**: See exactly what steps will be performed
- **Testing Scripts**: Validate command syntax and arguments
- **Safety**: Preview potentially destructive operations before execution
- **Debugging**: Understand command behavior without side effects

## Syntax

Add `--dry-run` flag to any claude-toolkit.sh command:

```bash
./scripts/claude-toolkit.sh <command> --dry-run [other-options]
```

## Supported Commands

All main commands support dry-run mode:

- `./scripts/claude-toolkit.sh install --dry-run`
- `./scripts/claude-toolkit.sh update --dry-run`  
- `./scripts/claude-toolkit.sh reinstall --dry-run`
- `./scripts/claude-toolkit.sh uninstall --dry-run`
- `./scripts/claude-toolkit.sh validate --dry-run`

## Dry-Run Output

In dry-run mode, commands output function names instead of executing operations:

### Install Dry-Run

```bash
./scripts/claude-toolkit.sh install --dry-run
```

Output:
```
dryrun:install_toolkit
```

### Update Dry-Run

```bash
./scripts/claude-toolkit.sh update --dry-run
```

Output:
```
dryrun:update_toolkit(git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git)
```

### Reinstall Dry-Run

```bash
./scripts/claude-toolkit.sh reinstall --dry-run
```

Output:
```
dryrun:reinstall_toolkit(git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git)
```

### Uninstall Dry-Run

```bash
./scripts/claude-toolkit.sh uninstall --dry-run
```

Output:
```
dryrun:uninstall_toolkit
```

### Validate Dry-Run

```bash
./scripts/claude-toolkit.sh validate --dry-run
```

Output:
```
dryrun:validate_toolkit
```

## Combining with Other Options

Dry-run can be combined with other options:

### With Shell Selection

```bash
./scripts/claude-toolkit.sh install --dry-run --shell=zsh
```

Shows what would happen for zsh-specific installation.

### With HTTPS Option

```bash
./scripts/claude-toolkit.sh install --dry-run --https
```

Shows repository URL that would be used:
```
dryrun:install_toolkit
```

### With Debug Mode

```bash
./scripts/claude-toolkit.sh install --dry-run --debug
```

Output includes debug information:
```
[INFO] Debug mode enabled
[DEBUG] command=install
[DEBUG] shell=
[DEBUG] dry_run=true
[DEBUG] use_https=false
[DEBUG] remote_repository=git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git
dryrun:install_toolkit
```

## Understanding Dry-Run Output

### Function Names

The output shows the main function that would be executed:

- `dryrun:install_toolkit` - Would perform installation
- `dryrun:update_toolkit(repo)` - Would update from specified repository
- `dryrun:reinstall_toolkit(repo)` - Would reinstall from repository
- `dryrun:uninstall_toolkit` - Would remove installation
- `dryrun:validate_toolkit` - Would validate installation

### Repository URLs

When repository operations are involved, the URL is shown:

```bash
# SSH URL (default)
dryrun:update_toolkit(git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git)

# HTTPS URL (with --https flag)
dryrun:update_toolkit(https://github.pie.apple.com/AI-for-Devs-Community/claude-toolkit.git)
```

## What Dry-Run Does NOT Do

### No File System Changes

- **No files created or modified**
- **No directories created or removed**
- **No symlinks created or removed**
- **No shell configuration changes**

### No Network Operations

- **No git clones or pulls**
- **No repository access**
- **No downloads**

### No System State Changes

- **No PATH modifications**
- **No permission changes**
- **No process execution**

## Practical Use Cases

### Pre-Installation Planning

```bash
# Check what installation would do
./scripts/claude-toolkit.sh install --dry-run

# Plan shell-specific installation
./scripts/claude-toolkit.sh install --dry-run --shell=fish

# Verify HTTPS installation plan
./scripts/claude-toolkit.sh install --dry-run --https
```

### Update Planning

```bash
# See what update would attempt
./scripts/claude-toolkit.sh update --dry-run

# Verify repository URL for update
./scripts/claude-toolkit.sh update --dry-run --https --debug
```

### Safety Verification

```bash
# Verify uninstall before executing
./scripts/claude-toolkit.sh uninstall --dry-run

# Check reinstall plan
./scripts/claude-toolkit.sh reinstall --dry-run
```

### Script Development

```bash
# Test argument parsing
./scripts/claude-toolkit.sh install --dry-run --shell=invalid-shell
# Will show validation error without attempting installation

# Verify command combinations
./scripts/claude-toolkit.sh reinstall --dry-run --https --debug
```

## Integration with Testing

### CI/CD Validation

```bash
# Validate script syntax in CI
./scripts/claude-toolkit.sh install --dry-run --shell=bash
./scripts/claude-toolkit.sh install --dry-run --shell=zsh
./scripts/claude-toolkit.sh install --dry-run --shell=fish

# Test all operations
for cmd in install update reinstall uninstall validate; do
    ./scripts/claude-toolkit.sh $cmd --dry-run
done
```

### Development Testing

```bash
# Test new options
./scripts/claude-toolkit.sh install --dry-run --new-option

# Verify error handling
./scripts/claude-toolkit.sh invalid-command --dry-run
```

## Limitations

### Partial Information

Dry-run shows planned operations but cannot show:

- **Dynamic decisions** made during execution
- **Error conditions** that might occur
- **Interactive prompts** that might appear
- **Network availability** issues

### State-Dependent Behavior

Some operations behave differently based on current state:

```bash
# If toolkit is not installed
./scripts/claude-toolkit.sh update --dry-run
# Shows: dryrun:update_toolkit(repo)

# But actual update might trigger reinstall if corruption detected
# Dry-run cannot predict this without examining system state
```

### Complex Workflows

Dry-run shows individual operation but not complex workflows:

```bash
# Reinstall involves: uninstall → clone → install
./scripts/claude-toolkit.sh reinstall --dry-run
# Shows: dryrun:reinstall_toolkit(repo)
# But doesn't show the internal sequence of operations
```

## Best Practices

### Always Test First

```bash
# Good practice: dry-run before executing
./scripts/claude-toolkit.sh uninstall --dry-run
# Review output, then:
./scripts/claude-toolkit.sh uninstall --yes
```

### Combine with Debug

```bash
# Get maximum information
./scripts/claude-toolkit.sh install --dry-run --debug
```

### Document Operations

```bash
# Save dry-run output for documentation
./scripts/claude-toolkit.sh install --dry-run --debug > install-plan.txt
```

### Validate Scripts

```bash
# Test script changes
for operation in install update reinstall uninstall; do
    echo "Testing $operation..."
    ./scripts/claude-toolkit.sh $operation --dry-run
done
```

## Error Handling in Dry-Run

### Argument Validation

Even in dry-run mode, argument validation still occurs:

```bash
./scripts/claude-toolkit.sh install --dry-run --shell=invalid
```

Output:
```
[ERROR] Unsupported shell: invalid (supported: bash, zsh, fish)
[INFO] Use --help for usage information
```

### Command Validation

Invalid commands are caught in dry-run:

```bash
./scripts/claude-toolkit.sh invalid-command --dry-run
```

Output:
```
[ERROR] Unknown command: invalid-command
[ERROR] Valid commands: install, uninstall, update
[INFO] Use --help for usage information
```

## Troubleshooting with Dry-Run

### Debug Complex Issues

```bash
# Understand what operations would be attempted
./scripts/claude-toolkit.sh reinstall --dry-run --debug

# Verify argument processing
./scripts/claude-toolkit.sh install --dry-run --shell=zsh --https --debug
```

### Test Fixes

```bash
# After making script changes, test with dry-run
./scripts/claude-toolkit.sh install --dry-run
# Verify no syntax errors or issues
```

### Validate Environment

```bash
# Test in different environments
SHELL=zsh ./scripts/claude-toolkit.sh install --dry-run
SHELL=bash ./scripts/claude-toolkit.sh install --dry-run
```

## Related Features

- **[Debug Mode](argument-processing.md#debug-mode)** - Detailed execution information
- **[Argument Processing](argument-processing.md)** - How arguments are parsed and validated
- **[Validation](validate.md)** - Verify actual system state
