# Dry-Run Mode for Slash Commands Setup

Preview slash commands setup operations without making any system modifications.

## Overview

The `--dry-run` flag enables preview mode for all `claude-slash.sh` operations. In dry-run mode, the script shows exactly which functions would be executed without performing any actual system changes, making it safe for understanding workflows, debugging, and validation.

## Basic Usage

```bash
# Preview install operation (default command)
./scripts/claude-slash.sh install --dry-run

# Preview reinstall operation
./scripts/claude-slash.sh reinstall --dry-run

# Preview uninstall operation  
./scripts/claude-slash.sh uninstall --dry-run

# Preview list operation
./scripts/claude-slash.sh list --dry-run
```

## Command Syntax

```bash
./scripts/claude-slash.sh <command> --dry-run [options]
```

### Core Operations with Dry-Run

| Operation | Command | Output Format |
|-----------|---------|---------------|
| **Install** | `install --dry-run` | `dryrun:install_templates(~/.claude/commands)` |
| **Reinstall** | `reinstall --dry-run` | `dryrun:reinstall_templates(~/.claude/commands)` |
| **Uninstall** | `uninstall --dry-run` | `dryrun:uninstall_templates(~/.claude/commands)` |
| **List** | `list --dry-run` | `dryrun:list_slash_commands(~/.claude/commands)` |

### Combining with Other Options

```bash
# Dry-run with verbose output
./scripts/claude-slash.sh install --dry-run --verbose

# Dry-run with specific list filter
./scripts/claude-slash.sh list --dry-run --filter toolkit-only

# Dry-run with custom repository
./scripts/claude-slash.sh install --dry-run --remote-repository <url>

# Dry-run with force flag
./scripts/claude-slash.sh uninstall --dry-run --yes
```

## What Dry-Run Shows

### Function Execution Preview

Dry-run mode prints the name of the main function that would be executed:

```bash
$ ./scripts/claude-slash.sh install --dry-run
dryrun:install_templates(~/.claude/commands)
```

```bash
$ ./scripts/claude-slash.sh reinstall --dry-run
dryrun:reinstall_templates(~/.claude/commands)
```

```bash
$ ./scripts/claude-slash.sh uninstall --dry-run
dryrun:uninstall_templates(~/.claude/commands)
```

```bash
$ ./scripts/claude-slash.sh list --dry-run
dryrun:list_slash_commands(~/.claude/commands)
```

### Preserved Output Messages

Start-up and configuration messages are still shown to provide context:

```bash
$ ./scripts/claude-slash.sh install --dry-run --verbose
[INFO] Verbose mode enabled
dryrun:install_templates(~/.claude/commands)
```

### Zero Exit Code

All dry-run operations exit with code 0 (success) regardless of the operation:

```bash
$ ./scripts/claude-slash.sh install --dry-run
dryrun:install_templates(~/.claude/commands)
$ echo $?
0
```

## Use Cases

### Workflow Understanding

Preview what functions would be called for different operations:

```bash
# Understand install workflow
./scripts/claude-slash.sh install --dry-run

# Compare with reinstall workflow
./scripts/claude-slash.sh reinstall --dry-run

# See uninstall process
./scripts/claude-slash.sh uninstall --dry-run
```

### Script Integration Testing

Test script integration without system changes:

```bash
#!/bin/bash
# Test script integration points

# Verify install command structure
if ./scripts/claude-slash.sh install --dry-run | grep -q "dryrun:install_templates"; then
    echo "Install operation properly structured"
fi

# Verify all operations have dry-run support
for op in install reinstall uninstall list; do
    if ./scripts/claude-slash.sh $op --dry-run >/dev/null 2>&1; then
        echo "$op operation supports dry-run"
    fi
done
```

### Debugging and Development

Validate script behavior during development:

```bash
# Check that new changes don't break dry-run mode
./scripts/claude-slash.sh install --dry-run
./scripts/claude-slash.sh reinstall --dry-run
./scripts/claude-slash.sh uninstall --dry-run
./scripts/claude-slash.sh list --dry-run
```

### Documentation and Training

Show users what operations are available:

```bash
# Demonstrate available operations
echo "Available operations:"
echo "Install:    $(./scripts/claude-slash.sh install --dry-run)"
echo "Reinstall:  $(./scripts/claude-slash.sh reinstall --dry-run)"
echo "Uninstall:  $(./scripts/claude-slash.sh uninstall --dry-run)"
echo "List:       $(./scripts/claude-slash.sh list --dry-run)"
```

## Safety Guarantees

### No System Modifications

Dry-run mode provides absolute guarantees against system changes:

- **No Directory Creation**: No `~/.claude/commands/` directory modifications
- **No File Operations**: No command files copied or removed
- **No Network Access**: No repository cloning or downloading
- **No Configuration Changes**: No shell or system configuration updates
- **No Cache Modifications**: No changes to repository cache or metadata

### Filesystem State Preservation

The filesystem state remains completely unchanged:

```bash
# Before dry-run
find ~/.claude/ -type f | wc -l
# 5

# Run dry-run operation
./scripts/claude-slash.sh install --dry-run

# After dry-run - same file count
find ~/.claude/ -type f | wc -l
# 5
```

### Process Isolation

Dry-run operations are completely isolated:

- **No Background Processes**: No long-running processes started
- **No Lock Files**: No temporary locks or state files created
- **No Registry Access**: No authentication or network operations
- **No Permission Changes**: No filesystem permissions modified

## Implementation Details

### Function-Level Implementation

Each main operation function includes dry-run detection:

```bash
install_templates() {
    local install_dir="$1"

    if [[ "$DRY_RUN" == true ]]; then
        echo "dryrun:install_templates($install_dir)"
        return 0
    fi
    
    # Normal installation logic...
}
```

### Early Exit Strategy

Dry-run detection happens immediately at function entry:

1. **Check Flag**: `[[ "$DRY_RUN" == true ]]`
2. **Print Name**: `echo "function_name"`
3. **Early Return**: `return 0`
4. **Skip Logic**: All normal operation logic is bypassed

### Preserved Context

While operations are skipped, important context is preserved:

- **Operation Messages**: Start-up messages still appear
- **Verbose Mode**: `--verbose` flag output still shown where applicable
- **Error Handling**: Script structure and error handling paths maintained

## Parameter Compatibility

Dry-run mode works with all parameter combinations:

### Repository Options

```bash
# Works with custom repositories
./scripts/claude-slash.sh install --dry-run --remote-repository <url>
dryrun:install_templates(~/.claude/commands)
```

### List Filters

```bash
# Works with list filtering
./scripts/claude-slash.sh list --dry-run --filter toolkit-only
dryrun:list_slash_commands(~/.claude/commands)
```

### Confirmation Flags

```bash
# Works with auto-confirmation
./scripts/claude-slash.sh uninstall --dry-run --yes
dryrun:uninstall_templates(~/.claude/commands)
```

### Verbose Output

```bash
# Combines with verbose mode
./scripts/claude-slash.sh install --dry-run --verbose
[INFO] Verbose mode enabled
dryrun:install_templates(~/.claude/commands)
```

## Error Scenarios

### Invalid Combinations

Dry-run mode validates parameter combinations normally:

```bash
$ ./scripts/claude-slash.sh list --dry-run --filter invalid-filter
[ERROR] Invalid filter value: invalid-filter
[ERROR] Valid filters: all, toolkit-only, user-only
```

### Help Requests

Help requests work normally with dry-run:

```bash
$ ./scripts/claude-slash.sh --help
Claude Code Slash Commands Installation Script

Usage: ./scripts/claude-slash.sh <command> [options]
[... full help output ...]
```

## Integration with Testing

Dry-run mode is essential for safe testing:

### Test Validation

```bash
# Validate that dry-run mode works for all operations
test_operations=("install" "reinstall" "uninstall" "list")
for op in "${test_operations[@]}"; do
    if ! ./scripts/claude-slash.sh $op --dry-run >/dev/null 2>&1; then
        echo "ERROR: Dry-run failed for $op operation"
        exit 1
    fi
done
```

### Regression Prevention

Dry-run mode helps prevent regressions during development:

```bash
# Before making changes, capture expected behavior
./scripts/claude-slash.sh install --dry-run > expected_install.txt
./scripts/claude-slash.sh reinstall --dry-run > expected_reinstall.txt

# After changes, verify behavior is unchanged
./scripts/claude-slash.sh install --dry-run > actual_install.txt
if ! diff expected_install.txt actual_install.txt; then
    echo "ERROR: Install dry-run behavior changed"
    exit 1
fi
```

## Performance Characteristics

### Fast Execution

Dry-run operations are extremely fast:

- **Immediate Return**: Functions return immediately after printing name
- **No I/O Operations**: No disk, network, or system operations
- **Minimal Processing**: Only argument parsing and basic validation
- **No Dependencies**: No external tool requirements

### Resource Usage

Dry-run mode has minimal resource impact:

- **Memory**: Only script parsing overhead
- **CPU**: Minimal processing for argument validation
- **Disk**: No filesystem operations
- **Network**: No network access attempted

## Comparison with Normal Operation

### Normal Install Operation
```bash
$ ./scripts/claude-slash.sh install
[INFO] Installing toolkit slash commands...
[SUCCESS] Installed 5 toolkit commands from local repository
```

### Dry-Run Install Operation
```bash
$ ./scripts/claude-slash.sh install --dry-run
dryrun:install_templates(~/.claude/commands)
```

The dry-run version shows the same initial context but exits immediately after printing the function name, providing a preview of the operation without any actual execution.

## Related Commands

- [`claude-code.sh --dry-run`](../claude-code/dry-run.md) - Dry-run mode for Claude Code installation
- [`--install`](install.md) - Install slash commands normally
- [`--list`](list.md) - List available slash commands normally
- [`--uninstall`](uninstall.md) - Remove slash commands normally
- [`--reinstall`](reinstall.md) - Reinstall slash commands normally
