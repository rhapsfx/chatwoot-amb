# Dry-Run Mode for Subagents Setup

Preview subagent setup operations without making any system modifications.

## Overview

The `--dry-run` flag enables preview mode for all `claude-agents` operations. In dry-run mode, the script shows exactly which functions would be executed without performing any actual system changes, making it safe for understanding workflows, debugging, and validation.

## Basic Usage

```bash
# Preview install operation
claude-agents install --dry-run

# Preview reinstall operation
claude-agents reinstall --dry-run

# Preview uninstall operation  
claude-agents uninstall --dry-run

# Preview list operation
claude-agents list --dry-run
```

## Command Syntax

```bash
claude-agents <command> --dry-run [options]
```

### Core Operations with Dry-Run

| Operation | Command | Output Format |
|-----------|---------|---------------|
| **Install** | `install --dry-run` | `dryrun:install_templates(agents, all, false)` |
| **Reinstall** | `reinstall --dry-run` | `dryrun:reinstall_templates(agents, all, false)` |
| **Uninstall** | `uninstall --dry-run` | `dryrun:uninstall_templates(agents, all, false, false)` |
| **List** | `list --dry-run` | `dryrun:list_templates(agents, all, compact, false)` |

### Combining with Other Options

```bash
# Dry-run with debug output
claude-agents install --dry-run --debug

# Dry-run with specific source
claude-agents install --dry-run --source claude-toolkit

# Dry-run with detailed format
claude-agents list --dry-run --format detailed

# Dry-run with force flag
claude-agents uninstall --dry-run --yes
```

## What Dry-Run Shows

### Function Execution Preview

Dry-run mode prints the name of the main function that would be executed:

```bash
$ claude-agents install --dry-run
dryrun:install_templates(agents, all, false)
```

```bash
$ claude-agents reinstall --dry-run --source claude-toolkit
dryrun:reinstall_templates(agents, claude-toolkit, false)
```

```bash
$ claude-agents uninstall --dry-run
dryrun:uninstall_templates(agents, all, false, false)
```

```bash
$ claude-agents list --dry-run --format detailed
dryrun:list_templates(agents, all, detailed, false)
```

### Preserved Output Messages

Start-up and configuration messages are still shown to provide context:

```bash
$ claude-agents install --dry-run --debug
[DEBUG] Template type: agents
[DEBUG] Source spec: all
dryrun:install_templates(agents, all, false)
```

### Zero Exit Code

All dry-run operations exit with code 0 (success) regardless of the operation:

```bash
$ claude-agents install --dry-run
dryrun:install_templates(agents, all, false)
$ echo $?
0
```

## Use Cases

### Workflow Understanding

Preview what functions would be called for different operations:

```bash
# Understand install workflow
claude-agents install --dry-run

# Compare with reinstall workflow
claude-agents reinstall --dry-run

# See uninstall process
claude-agents uninstall --dry-run --source claude-toolkit
```

### Script Integration Testing

Test script integration without system changes:

```bash
#!/bin/bash
# Test script integration points

# Verify install command structure
if claude-agents install --dry-run | grep -q "dryrun:install_templates"; then
    echo "Install operation properly structured"
fi

# Verify all operations have dry-run support
for op in install reinstall uninstall list; do
    if claude-agents $op --dry-run >/dev/null 2>&1; then
        echo "$op operation supports dry-run"
    fi
done
```

### Debugging and Development

Validate script behavior during development:

```bash
# Check that new changes don't break dry-run mode
claude-agents install --dry-run
claude-agents reinstall --dry-run
claude-agents uninstall --dry-run
claude-agents list --dry-run
```

### Documentation and Training

Show users what operations are available:

```bash
# Demonstrate available operations
echo "Available operations:"
echo "Install:    $(claude-agents install --dry-run)"
echo "Reinstall:  $(claude-agents reinstall --dry-run)"
echo "Uninstall:  $(claude-agents uninstall --dry-run)"
echo "List:       $(claude-agents list --dry-run)"
```

## Safety Guarantees

### No System Modifications

Dry-run mode provides absolute guarantees against system changes:

- **No Directory Creation**: No `~/.claude/agents/` directory modifications
- **No File Operations**: No subagent files copied or removed
- **No Network Access**: No repository cloning or downloading
- **No Configuration Changes**: No shell or system configuration updates
- **No Cache Modifications**: No changes to repository cache or metadata

### Filesystem State Preservation

The filesystem state remains completely unchanged:

```bash
# Before dry-run
find ~/.claude/ -type f | wc -l
# 3

# Run dry-run operation
claude-agents install --dry-run

# After dry-run - same file count
find ~/.claude/ -type f | wc -l
# 3
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
    local template_type="$1"
    local source_spec="$2"
    local porcelain="$3"

    if [[ "$DRY_RUN" == true ]]; then
        echo "dryrun:install_templates($template_type, $source_spec, $porcelain)"
        return 0
    fi
    
    # Normal installation logic...
}
```

### Early Exit Strategy

Dry-run detection happens immediately at function entry:

1. **Check Flag**: `[[ "$DRY_RUN" == true ]]`
2. **Print Name**: `echo "function_name(parameters)"`
3. **Early Return**: `return 0`
4. **Skip Logic**: All normal operation logic is bypassed

### Preserved Context

While operations are skipped, important context is preserved:

- **Operation Messages**: Start-up messages still appear
- **Debug Mode**: `--debug` flag output still shown where applicable
- **Error Handling**: Script structure and error handling paths maintained

## Parameter Compatibility

Dry-run mode works with all parameter combinations:

### Source Options

```bash
# Works with specific sources
claude-agents install --dry-run --source claude-toolkit
dryrun:install_templates(agents, claude-toolkit, false)

# Works with multiple sources
claude-agents install --dry-run --source claude-toolkit,team-alpha
dryrun:install_templates(agents, claude-toolkit,team-alpha, false)
```

### List Formats

```bash
# Works with list formatting
claude-agents list --dry-run --format detailed
dryrun:list_templates(agents, all, detailed, false)
```

### Confirmation Flags

```bash
# Works with auto-confirmation
claude-agents uninstall --dry-run --yes
dryrun:uninstall_templates(agents, all, true, false)
```

### Debug Output

```bash
# Combines with debug mode
claude-agents install --dry-run --debug
[DEBUG] Template type: agents
[DEBUG] Source spec: all
dryrun:install_templates(agents, all, false)
```

## Error Scenarios

### Invalid Combinations

Dry-run mode validates parameter combinations normally:

```bash
$ claude-agents list --dry-run --format invalid-format
[ERROR] Invalid --format for 'list' command: invalid-format (valid: compact, detailed)
```

### Help Requests

Help requests work normally with dry-run:

```bash
$ claude-agents --help
Claude Code Subagents Installation Script

Usage: claude-agents <command> [options]
[... full help output ...]
```

## Integration with Testing

Dry-run mode is essential for safe testing:

### Test Validation

```bash
# Validate that dry-run mode works for all operations
test_operations=("install" "reinstall" "uninstall" "list")
for op in "${test_operations[@]}"; do
    if ! claude-agents $op --dry-run >/dev/null 2>&1; then
        echo "ERROR: Dry-run failed for $op operation"
        exit 1
    fi
done
```

### Regression Prevention

Dry-run mode helps prevent regressions during development:

```bash
# Before making changes, capture expected behavior
claude-agents install --dry-run > expected_install.txt
claude-agents reinstall --dry-run > expected_reinstall.txt

# After changes, verify behavior is unchanged
claude-agents install --dry-run > actual_install.txt
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
$ claude-agents install
Installing files from source(s): all
✅ Successfully installed 4 file(s)

Note: Restart Claude Code to refresh available subagents
```

### Dry-Run Install Operation
```bash
$ claude-agents install --dry-run
dryrun:install_templates(agents, all, false)
```

The dry-run version shows the same initial context but exits immediately after printing the function name, providing a preview of the operation without any actual execution.

## Related Commands

- [`install`](install.md) - Install subagents normally
- [`list`](list.md) - List available subagents normally
- [`uninstall`](uninstall.md) - Remove subagents normally
- [`reinstall`](reinstall.md) - Reinstall subagents normally
- **claude-template-sources commands:**
  - [`claude-template-sources add`](../claude-template-sources/add.md) - Add template source repositories
  - [`claude-template-sources list`](../claude-template-sources/list.md) - List configured sources
  - [`claude-template-sources remove`](../claude-template-sources/remove.md) - Remove source configuration