# Dry-Run Mode

Preview script operations without making system modifications by printing simplified function names.

## Overview

The `--dry-run` mode provides a safe way to preview what the installation script would do without actually performing any operations. This is particularly useful for validating parameters and ensuring the script will behave as expected before running it on production systems.

In dry-run mode, only the top-level operation functions print their names in the format `dryrun:function_name(parameters)` and exit with success, without performing any actual system modifications.

## Basic Usage

```bash
# Preview default installation
./scripts/claude-code.sh install --dry-run

# Preview specific version installation
./scripts/claude-code.sh install --version 0.0.85 --dry-run

# Preview reinstall operation
./scripts/claude-code.sh reinstall --dry-run

# Preview version switching
./scripts/claude-code.sh use --version 0.0.85 --dry-run

# Preview uninstall operation
./scripts/claude-code.sh uninstall --all --dry-run
```

## Command Syntax

```bash
./scripts/claude-code.sh <command> --dry-run [options]
```

### Supported Operations

All standard operations work with `--dry-run`:

| Operation | Description | Output Format |
|-----------|-------------|---------------|
| `install` | Preview installation process | `dryrun:install_claude_code(version)` |
| `reinstall` | Preview reinstall operation | `dryrun:reinstall_claude_code(version)` |
| `use --version <version>` | Preview version switching | `dryrun:use_claude_version(version)` |
| `uninstall` | Preview uninstall operation | `dryrun:uninstall_claude_code(version)` |
| `list` | Preview version listing | `dryrun:list_claude_versions(mode)` |

### Compatible Options

Dry-run mode works with all standard options:

| Option | Description |
|--------|-------------|
| `--version <version>` | Show specific version in dry-run output |
| `--nodejs-version <version>` | Compatible but not shown in simplified output |
| `--debug` | Show additional logging during preview |
| `--shell <shell>` | Compatible but not shown in simplified output |
| `--yes`, `-y`, `--force` | Compatible but not needed for dry-run |

## Execution Flow Preview

### Installation Flow (Default)

```bash
$ ./scripts/claude-code.sh install --dry-run
[INFO] No operation specified, defaulting to --install
[INFO] Debug mode enabled
dryrun:install_claude_code()
```

### Specific Version Installation

```bash
$ ./scripts/claude-code.sh install --version 0.0.85 --dry-run
[INFO] No operation specified, defaulting to --install
[INFO] Debug mode enabled
dryrun:install_claude_code(0.0.85)
```

### Reinstall Flow

```bash
$ ./scripts/claude-code.sh reinstall --dry-run
[INFO] Debug mode enabled
dryrun:reinstall_claude_code()
```

### Version Switching Flow

```bash
$ ./scripts/claude-code.sh use --version 0.0.85 --dry-run
[INFO] Debug mode enabled
dryrun:use_claude_version(0.0.85)
```

### Uninstall Flow

```bash
$ ./scripts/claude-code.sh uninstall --dry-run
[INFO] Debug mode enabled
dryrun:uninstall_claude_code()
```

### List Flow

```bash
$ ./scripts/claude-code.sh list --dry-run
dryrun:list_claude_versions(available)
```

## Safety Features

### No System Modifications

Dry-run mode guarantees **zero system modifications**:

- No files or directories created
- No downloads performed
- No shell configurations modified  
- No network requests made
- No system state changes

### Simplified Output  

The dry-run mode uses a simplified approach:

- **Top-level functions only** - Only main operation functions show output
- **Consistent format** - All outputs use `dryrun:function_name(parameters)` format
- **Parameter validation** - Command-line arguments are still validated
- **Quick execution** - Minimal processing for fast feedback

## Use Cases

### Parameter Validation

```bash
# Verify version parameter is accepted
./scripts/claude-code.sh install --version 0.0.85 --dry-run

# Check operation selection
./scripts/claude-code.sh use --version 0.0.83 --dry-run

# Validate uninstall syntax
./scripts/claude-code.sh uninstall --all --dry-run
```

### Operation Preview

```bash
# Preview what install command would do
./scripts/claude-code.sh install --version 0.0.85 --dry-run

# Preview reinstall behavior
./scripts/claude-code.sh reinstall --version 0.0.83 --dry-run

# Preview version switching
./scripts/claude-code.sh use --version 0.0.84 --dry-run
```

### Integration with Testing

The dry-run mode is comprehensively tested to ensure:

- All operations produce correct dry-run output
- Parameter validation works correctly
- No side effects occur during dry-run execution
- Exit codes are appropriate for each operation
- Logging messages are preserved

## Output Interpretation

### Function Names

Each `dryrun:function_name(parameters)` line represents the main operation that would be executed:

- `dryrun:install_claude_code(version)` - Installation operation with optional version
- `dryrun:reinstall_claude_code(version)` - Reinstallation operation  
- `dryrun:use_claude_version(version)` - Version switching operation
- `dryrun:uninstall_claude_code(version)` - Uninstall operation
- `dryrun:list_claude_versions(mode)` - Version listing operation

### Logging Messages

Lines with `[INFO]`, `[SUCCESS]`, `[ERROR]`, or `[WARNING]` prefixes show the logging output that would be displayed during actual execution, particularly initial setup and parameter processing.

## Examples

### Basic Operations

```bash
# Default installation
$ ./scripts/claude-code.sh install --dry-run
[INFO] No operation specified, defaulting to --install
[INFO] Debug mode enabled
dryrun:install_claude_code()

# Install specific version
$ ./scripts/claude-code.sh install --version 0.0.85 --dry-run
[INFO] No operation specified, defaulting to --install
[INFO] Debug mode enabled
dryrun:install_claude_code(0.0.85)

# Switch versions
$ ./scripts/claude-code.sh use --version 0.0.83 --dry-run
[INFO] Debug mode enabled
dryrun:use_claude_version(0.0.83)

# Uninstall all versions
$ ./scripts/claude-code.sh uninstall --all --dry-run
[INFO] Debug mode enabled
dryrun:uninstall_claude_code()
```

### With Additional Options

```bash
# Reinstall with debug output
$ ./scripts/claude-code.sh reinstall --debug --dry-run
[INFO] Debug mode enabled
dryrun:reinstall_claude_code()

# List installed versions only
$ ./scripts/claude-code.sh list --mode installed --dry-run
dryrun:list_claude_versions(installed)
```

## Best Practices

1. **Always test complex operations** - Run dry-run before actual execution
2. **Validate parameters** - Check that the expected version appears in parentheses
3. **Use for automation** - Incorporate dry-run checks into scripts and CI/CD pipelines
4. **Quick syntax validation** - Use dry-run to verify command syntax before execution

The simplified dry-run mode provides fast, reliable validation of script operations without the complexity of detailed execution flow preview.
