# Claude Toolkit Documentation

Complete guide to using and managing the Claude Toolkit.

## Overview

The Claude Toolkit provides a comprehensive approach to managing Claude Code installations and slash commands through five specialized scripts:

- **`claude-toolkit.sh`** - Core infrastructure and shell integration
- **`claude-code.sh`** - Claude Code installation and version management
- **`claude-slash.sh`** - Slash commands management
- **`claude-agents.sh`** - Subagents management
- **`claude-template-sources.sh`** - Template source repositories management

## Advanced Usage

### Version Management

#### Installing Specific Versions
```bash
# Install specific Claude Code version
claude-code install --version 0.0.85

# Install with custom Node.js version
claude-code install --nodejs-version 18.20.0

# Switch between installed versions  
claude-code use --version 0.0.84

# List installed versions
claude-code list --mode installed

# List available versions
claude-code list --mode available

# Reinstall current version
claude-code reinstall
```

#### Multiple Version Management
```bash
# Install multiple versions
claude-code install --version 0.0.84
claude-code install --version 0.0.85

# Switch between them
claude-code use --version 0.0.84
claude-code use --version 0.0.85

# Remove specific version
claude-code uninstall --version 0.0.84

# Remove all versions
claude-code uninstall --all
```

### Slash Commands Management

#### Advanced Slash Commands Operations
```bash
# List all commands
claude-slash list

# List commands from specific source
claude-slash list --source claude-toolkit
claude-slash list --source user
claude-slash list --source team-alpha

# List commands from multiple sources
claude-slash list --source user,claude-toolkit

# List with detailed information
claude-slash list --format detailed

# Source management
claude-template-sources add team-alpha git@github.com:myorg/commands.git
claude-template-sources list
claude-template-sources remove team-alpha

# Install from specific sources
claude-slash install --source claude-toolkit
claude-slash install --source user,team-alpha

# Reinstall from repository
claude-slash reinstall
claude-slash reinstall --source claude-toolkit

# Uninstall commands from specific source (preserves other sources)
claude-slash uninstall --source team-alpha

# Preview installation (dry run)
claude-slash install --dry-run
```

### Subagents Management

#### Advanced Subagents Operations
```bash
# List all subagents
claude-agents list

# List subagents from specific source
claude-agents list --source claude-toolkit
claude-agents list --source user
claude-agents list --source team-alpha

# List subagents from multiple sources
claude-agents list --source user,claude-toolkit

# List with detailed information
claude-agents list --format detailed

# Source management (shared with slash commands)
claude-template-sources add team-alpha git@github.com:myorg/agents.git
claude-template-sources list
claude-template-sources remove team-alpha

# Install from specific sources
claude-agents install --source claude-toolkit
claude-agents install --source user,team-alpha

# Reinstall from repository
claude-agents reinstall
claude-agents reinstall --source claude-toolkit

# Uninstall subagents from specific source (preserves other sources)
claude-agents uninstall --source team-alpha

# Preview installation (dry run)
claude-agents install --dry-run
```

### Toolkit Infrastructure Management

#### Core Infrastructure Operations
```bash
# Initial installation (one-time)
./scripts/claude-toolkit.sh install

# Normal usage (after installation)
claude-toolkit update      # Update toolkit from remote repository
claude-toolkit reinstall   # Reinstall toolkit completely
claude-toolkit validate    # Validate installation
claude-toolkit uninstall   # Remove toolkit infrastructure

# Preview operations (dry run)
claude-toolkit install --dry-run
```

## Custom Slash Commands

### Creating Your Own Commands

Use the built-in `/add-command` helper:

```bash
# Inside Claude Code
/add-command project my-review --template code-review
/add-command user helper --namespace tools --description "Personal helper"
```

### Command Templates

Available templates for quick command creation:

- **`code-review`** - For reviewing code with focus areas
- **`bug-report`** - For generating structured bug reports  
- **`documentation`** - For creating or updating documentation
- **`security-audit`** - For security-focused code analysis
- **`optimization`** - For performance and optimization suggestions
- **`test-generation`** - For generating test cases

### Manual Command Creation

Commands are Markdown files in `~/.claude/commands/` with YAML frontmatter:

```markdown
---
description: Your command description
argument-hint: <expected-arguments>
allowed-tools: Read, Write, Bash
---

# Your Command

Instructions for Claude Code on what to do when this command is invoked.

Arguments provided by the user: `$ARGUMENTS`
```

## Shell Integration

### Supported Shells

The toolkit automatically configures:
- **bash**: `~/.bashrc` or `~/.bash_profile` (macOS)
- **zsh**: `~/.zshrc`  
- **fish**: `~/.config/fish/config.fish`

### Manual Configuration

If automatic configuration fails:

**For bash/zsh:**
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**For fish:**
```fish
echo 'set -gx PATH "$HOME/.local/bin" $PATH' >> ~/.config/fish/config.fish
source ~/.config/fish/config.fish
```

### Target Specific Shells

```bash
# Configure only for zsh (initial installation)
./scripts/claude-toolkit.sh install --shell=zsh

# Configure components for specific shells (after toolkit installation)
claude-code install --shell=bash
```

## Global Options

All scripts support these global options:

### Debug and Development
```bash
# Enable debug output
claude-code install --debug

# Preview operations without execution
claude-slash install --dry-run

# Skip confirmation prompts
claude-toolkit uninstall --yes

# Use HTTPS instead of SSH for git operations (initial installation)
./scripts/claude-toolkit.sh install --https
```

### Machine-Readable Output
```bash
# Enable porcelain format for scripting
claude-code list --porcelain
```

## Security

- **Isolated Installation**: All components install to user directories (`~/.local/`)
- **No System Modifications**: No sudo required, no system files modified
- **Reversible Operations**: All installations can be cleanly uninstalled
- **XDG Compliance**: Follows XDG Base Directory specification

## Troubleshooting

For installation and usage issues, see:

- **[Installation Guide](installation.md#troubleshooting-installation)** - Complete troubleshooting guide
- **[Claude Code Management](claude-code/troubleshooting.md)** - Claude Code specific issues
- **[Slash Commands Management](claude-slash/troubleshooting.md)** - Slash commands issues
- **[Subagents Management](claude-agents/troubleshooting.md)** - Subagents issues

### Quick Debug Commands

```bash
# Check if commands are available
which claude claude-toolkit claude-code claude-slash claude-agents

# Check PATH configuration
echo $PATH | grep ".local/bin"

# Verify installation directories
ls -la ~/.local/bin/
ls -la ~/.local/share/claude*
ls -la ~/.claude/commands/
ls -la ~/.claude/agents/

# Test installations
claude-toolkit validate
claude-code list --mode installed
claude-slash list
claude-agents list
```

## Integration Examples

### Development Workflows

```bash
# Complete setup script (initial installation)
./scripts/claude-toolkit.sh install
claude-code install
claude-slash install
claude-agents install

# Quick project setup (normal usage)
cd your-project
claude
/review-codebase
```

### Team Standardization

```bash
# Standard team setup (initial installation)
./scripts/claude-toolkit.sh install --yes
claude-code install --yes  
claude-slash install --yes
claude-agents install --yes

# Add team-specific template sources (for both commands and subagents)
claude-template-sources add team-alpha git@github.com:myorg/alpha-templates.git
claude-template-sources add team-beta git@github.com:myorg/beta-templates.git
claude-slash install --source team-alpha,team-beta
claude-agents install --source team-alpha,team-beta

# Verify team installation
claude-template-sources list
claude-slash list --source claude-toolkit,team-alpha,team-beta
claude-agents list --source claude-toolkit,team-alpha,team-beta
```

### Automation and Scripting

```bash
# Automated installation with specific versions (initial setup)
./scripts/claude-toolkit.sh install --dry-run  # Preview
claude-code install --version 0.0.85 --nodejs-version 22.17.1
claude-slash install --yes
claude-agents install --yes

# Add and install from custom sources
claude-template-sources add myorg-tools git@github.com:myorg/dev-tools.git
claude-slash install --source myorg-tools
claude-agents install --source myorg-tools

# Batch operations (normal usage)
for cmd in claude-toolkit claude-code claude-slash claude-agents; do
    $cmd validate 2>/dev/null || echo "$cmd needs attention"
done

### Source management automation
claude-template-sources list --porcelain | while IFS=$'\t' read -r name url; do
    echo "Source: $name -> $url"
done
```

## Related Documentation

- **[Installation Guide](installation.md)** - Complete installation instructions
- **[Architecture](architecture.md)** - System design and component relationships  
- **[Claude Code Management](claude-code/index.md)** - Detailed claude-code.sh usage
- **[Slash Commands Management](claude-slash/index.md)** - Detailed claude-slash.sh usage
- **[Subagents Management](claude-agents/index.md)** - Detailed claude-agents.sh usage
- **[Template Sources Management](claude-template-sources/index.md)** - Detailed claude-template-sources.sh usage
