# Argument Processing

Detailed guide to command-line argument parsing and validation in claude-toolkit.sh.

## Overview

The `claude-toolkit.sh` script implements a sophisticated three-stage argument processing pipeline:

1. **Parse**: Pure syntactic parsing of command-line arguments
2. **Validate**: Semantic validation and constraint checking
3. **Interpret**: Variable assignment and command execution

This architecture ensures robust error handling and clear separation of concerns.

## Three-Stage Processing Pipeline

### Stage 1: Parse (`parse_arguments()`)

**Purpose**: Pure syntactic parsing without semantic validation.

**Input**: Raw command-line arguments
**Output**: Key-value pairs for all recognized patterns

```bash
# Example input
./scripts/claude-toolkit.sh install --shell=zsh --debug

# Parsed output (internal format)
command	install
shell	zsh  
debug	true
```

**Features**:
- Handles both `--flag` and `--flag=value` syntax
- Recognizes unknown options (marks for later validation)
- Never fails - captures all input for validation stage

### Stage 2: Validate (`validate_arguments()`)

**Purpose**: Semantic validation and constraint checking.

**Input**: Parsed key-value pairs  
**Output**: Success/failure with detailed error messages

```bash
# Validation checks
- Command exists and is supported
- Required option values are provided
- Shell names are valid (bash, zsh, fish)
- Option combinations are allowed
```

**Error Examples**:
```bash
./scripts/claude-toolkit.sh --shell
# Error: --shell requires a value

./scripts/claude-toolkit.sh install --shell=invalid  
# Error: Unsupported shell: invalid (supported: bash, zsh, fish)

./scripts/claude-toolkit.sh unknown-command
# Error: Unknown command: unknown-command
```

### Stage 3: Interpret (`interpret_arguments()`)

**Purpose**: Set variables and execute main logic.

**Input**: Validated arguments
**Output**: Command execution

```bash
# Sets global variables
DEBUG="$debug"
DRY_RUN="$dry_run"

# Calls appropriate function
install_toolkit "$remote_repository" "$shell"
```

## Supported Arguments

### Commands

Commands are the primary operation to perform:

| Command | Description |
|---------|-------------|
| `install` | Install Claude Toolkit (default if none specified) |
| `reinstall` | Reinstall Claude Toolkit completely |  
| `uninstall` | Remove Claude Toolkit installation |
| `update` | Update Claude Toolkit from remote repository |
| `validate` | Validate Claude Toolkit installation |

**Examples**:
```bash
./scripts/claude-toolkit.sh install
./scripts/claude-toolkit.sh                    # Defaults to install
./scripts/claude-toolkit.sh update
```

### Global Options

Options that apply to all commands:

| Option | Values | Description |
|--------|---------|-------------|
| `--shell` | `bash`, `zsh`, `fish` | Target specific shell |
| `--https` | flag | Use HTTPS git URLs instead of SSH |
| `--dry-run` | flag | Preview operations without executing |
| `--debug` | flag | Enable debug output |
| `--yes`, `-y`, `--force` | flag | Skip confirmation prompts |
| `--help`, `-h` | flag | Show help message |

### Internal Options

Options used internally (not for general use):

| Option | Description |
|--------|-------------|
| `--remote-repository` | Override default repository URL |

## Argument Syntax

### Flag Options

Simple boolean flags:

```bash
./scripts/claude-toolkit.sh install --https
./scripts/claude-toolkit.sh install --debug  
./scripts/claude-toolkit.sh install --dry-run
./scripts/claude-toolkit.sh uninstall --yes
./scripts/claude-toolkit.sh uninstall -y      # Short form
./scripts/claude-toolkit.sh uninstall --force # Alternative form
```

### Value Options

Options that require values:

```bash
# Space-separated syntax
./scripts/claude-toolkit.sh install --shell bash
./scripts/claude-toolkit.sh install --shell zsh

# Equals syntax  
./scripts/claude-toolkit.sh install --shell=bash
./scripts/claude-toolkit.sh install --shell=zsh
```

### Option Combinations

Multiple options can be combined:

```bash
./scripts/claude-toolkit.sh install --shell=zsh --https --debug
./scripts/claude-toolkit.sh reinstall --dry-run --debug
./scripts/claude-toolkit.sh uninstall --shell bash --yes
```

## Validation Rules

### Command Validation

1. **Recognized Commands**: Only specific commands are allowed
2. **Single Command**: Exactly one command per invocation
3. **Help Precedence**: `--help` overrides command validation

### Option Validation

1. **Required Values**: Options like `--shell` must have values
2. **Valid Values**: Shell must be bash, zsh, or fish
3. **No Conflicts**: Currently no conflicting options defined

### Argument Order

Arguments can be provided in any order:

```bash
# These are equivalent
./scripts/claude-toolkit.sh install --shell=zsh --debug
./scripts/claude-toolkit.sh --debug install --shell=zsh
./scripts/claude-toolkit.sh --shell=zsh --debug install
```

## Error Handling

### Parse Errors

Parse stage never fails, but marks issues:

```bash
./scripts/claude-toolkit.sh install --unknown-flag
# Parsed as: unknown_option=--unknown-flag
# Validated as error in next stage
```

### Validation Errors

Validation provides specific error messages:

```bash
./scripts/claude-toolkit.sh install --shell
# [ERROR] --shell requires a value

./scripts/claude-toolkit.sh install --shell=invalid
# [ERROR] Unsupported shell: invalid (supported: bash, zsh, fish)

./scripts/claude-toolkit.sh unknown-command  
# [ERROR] Unknown command: unknown-command
# [ERROR] Valid commands: install, uninstall, update
```

### Help Requests

Help requests bypass all validation:

```bash
./scripts/claude-toolkit.sh --help
./scripts/claude-toolkit.sh install --help    # Error: help after command
./scripts/claude-toolkit.sh -h
```

## Debug Mode

### Enabling Debug

```bash
./scripts/claude-toolkit.sh install --debug
```

### Debug Output

Shows internal processing details:

```bash
[INFO] Debug mode enabled
[DEBUG] command=install
[DEBUG] shell=
[DEBUG] dry_run=false
[DEBUG] use_https=false  
[DEBUG] remote_repository=git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git
```

### Debug with Dry-Run

Combine for maximum information:

```bash
./scripts/claude-toolkit.sh install --debug --dry-run
```

Shows argument processing without execution.

## Default Values

### Command Defaults

- **No command specified**: Defaults to `install`
- **Repository URL**: Uses SSH by default, HTTPS with `--https`
- **Shell**: Auto-detects available shells if not specified

### Environment Integration

Some defaults come from environment:

```bash
# These environment variables affect behavior
DEBUG="${DEBUG:-false}"
DRY_RUN="${DRY_RUN:-false}"  
PORCELAIN="${PORCELAIN:-false}"
```

## Advanced Usage

### Repository URL Override

```bash
# Use custom repository (internal option)
./scripts/claude-toolkit.sh install --remote-repository git@custom.com:repo.git
```

### Environment Variable Integration

```bash
# Pre-set debug mode
DEBUG=true ./scripts/claude-toolkit.sh install

# Pre-set dry-run mode  
DRY_RUN=true ./scripts/claude-toolkit.sh install
```

### Shell Detection Override

```bash
# Force specific shell even if others are available
./scripts/claude-toolkit.sh install --shell=bash
```

## Argument Processing Examples

### Basic Install

```bash
./scripts/claude-toolkit.sh install
```

**Processing**:
1. **Parse**: `command=install`
2. **Validate**: Command 'install' is valid ✓
3. **Interpret**: Call `install_toolkit()`

### Install with Options

```bash
./scripts/claude-toolkit.sh install --shell=zsh --https --debug
```

**Processing**:
1. **Parse**: `command=install, shell=zsh, https=true, debug=true`
2. **Validate**: All values valid ✓
3. **Interpret**: Set `DEBUG=true`, use HTTPS repository, call `install_toolkit()`

### Error Case

```bash
./scripts/claude-toolkit.sh install --shell=invalid
```

**Processing**:
1. **Parse**: `command=install, shell=invalid` ✓
2. **Validate**: Shell 'invalid' not supported ✗
3. **Error**: Display error message and exit

### Help Request

```bash
./scripts/claude-toolkit.sh --help
```

**Processing**:
1. **Parse**: `help=true` ✓
2. **Validate**: Skipped (help requested) ✓
3. **Interpret**: Display help and exit

## Implementation Details

### Internal Data Flow

```bash
# Raw arguments
./scripts/claude-toolkit.sh install --shell=zsh

# After parse_arguments()
"command\tinstall\nshell\tzsh\n"

# After validate_arguments()  
Success (no errors)

# After interpret_arguments()
command="install"
shell="zsh"
# ... execute install_toolkit("repo", "zsh")
```

### Error Propagation

```bash
# Validation failure stops processing
validate_arguments() {
    # Returns non-zero exit code on error
    return 1
}

# Main function handles validation failure
if ! validation_result=$(echo "$parsed_args" | validate_arguments 2>&1); then
    # Display errors and exit
    log_error "$validation_result"
    return 1
fi
```

## Testing Argument Processing

### Syntax Testing

```bash
# Test valid combinations
./scripts/claude-toolkit.sh install --dry-run
./scripts/claude-toolkit.sh update --https --dry-run
./scripts/claude-toolkit.sh uninstall --yes --dry-run

# Test error cases
./scripts/claude-toolkit.sh install --shell=invalid --dry-run
./scripts/claude-toolkit.sh unknown-command --dry-run
```

### Debug Testing

```bash
# See internal processing
./scripts/claude-toolkit.sh install --shell=zsh --debug --dry-run
```

### Validation Testing

```bash
# Test all supported shells
for shell in bash zsh fish; do
    ./scripts/claude-toolkit.sh install --shell=$shell --dry-run
done

# Test error handling
for shell in invalid sh csh; do  
    ./scripts/claude-toolkit.sh install --shell=$shell --dry-run 2>&1 | grep -q "ERROR"
done
```

## Troubleshooting

### Common Issues

1. **Command not recognized**:
   ```bash
   [ERROR] Unknown command: instal
   # Fix: Check spelling, use 'install'
   ```

2. **Missing option value**:
   ```bash
   [ERROR] --shell requires a value
   # Fix: Provide shell name: --shell=bash
   ```

3. **Invalid option value**:
   ```bash  
   [ERROR] Unsupported shell: sh (supported: bash, zsh, fish)
   # Fix: Use supported shell name
   ```

4. **Help after command**:
   ```bash
   [ERROR] Use --help before command for usage information
   # Fix: ./scripts/claude-toolkit.sh --help
   ```

### Debugging Process

1. **Use dry-run**: `--dry-run` to test without execution
2. **Use debug**: `--debug` to see internal processing
3. **Check help**: `--help` for syntax reference
4. **Test incrementally**: Start with simple arguments, add complexity

## Related Documentation

- **[Dry-Run Mode](dry-run.md)** - Testing arguments without execution
- **[Install Command](install.md)** - Detailed install argument usage
- **[Update Command](update.md)** - Update-specific arguments
- **[Troubleshooting](troubleshooting.md)** - Resolving argument issues
