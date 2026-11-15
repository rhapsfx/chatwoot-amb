# Claude Toolkit

<p align="left">
  <img src="./docs/assets/robot_with_toolbox_40.png" alt="Project Logo" width="150"/>
</p>

A comprehensive toolkit for managing Claude Code installations and slash commands.

## Quick Start (30 seconds)

```bash
# Initial installation (one-time setup)
git clone git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git
cd claude-toolkit
./scripts/claude-toolkit.sh install
exec $SHELL -l

# Install components (using global commands)
claude-code install
claude-slash install
claude-agents install
```

**Ready!** Type `claude` to start, then try these inside Claude Code:
- `/smart-commit` - Intelligent commit analysis and organization
- `/review-codebase` - Automated code analysis with security insights  
- `/add-command` - Interactive wizard for building custom slash commands

**Problems with installation?** See the **[Installation Guide](docs/installation.md)** for alternative methods and troubleshooting.

## What You Get

### 📦 Component-Based Management
- **Claude Toolkit**: Core infrastructure and shell integration
- **Claude Code**: Multiple Claude Code versions with easy switching
- **Slash Commands**: Powerful development workflow commands
- **Subagents**: Specialized AI assistants for task-specific workflows

### 🤖 Powerful Slash Commands
- **`/smart-commit`**: Analyzes changes and suggests structured commits
- **`/review-codebase`**: Security-focused code analysis and best practices
- **`/add-command`**: Create custom slash commands interactively
- **`/quick-commit`**: Streamlined workflow for simple changes
- **`/solid-analysis`**: SOLID principles analysis for code architecture

### 🎯 Specialized Subagents
- **`architect`**: Expert software architect for comprehensive architectural analysis and design guidance
- **`test-writer-debugger`**: Expert test writer and debugger for comprehensive test suite management
- **`statusline-setup`**: Specialized agent for configuring Claude Code status line settings
- **`output-style-setup`**: Expert agent for creating custom Claude Code output styles

### 🔧 Enterprise-Ready
- XDG-compliant installation (no system interference)
- Multi-shell support (bash, zsh, fish)
- Apple infrastructure integration
- Comprehensive testing framework

## Basic Usage

### Start Using Claude Code
```bash
# Navigate to your project
cd /path/to/your/project

# Start Claude Code  
claude

# Inside Claude Code, try these commands:
/smart-commit     # Analyze changes and suggest commits
/review-codebase  # Review your codebase with security insights
/add-command      # Create custom slash commands
```

### Manage Your Installation
```bash
# Check Claude Code versions
claude-code list --mode installed

# Switch Claude Code version
claude-code use --version 0.0.84

# List slash commands from all sources
claude-slash list

# List only toolkit commands
claude-slash list --source claude-toolkit

# List subagents from all sources  
claude-agents list

# Update slash commands and subagents
claude-slash reinstall
claude-agents reinstall

# Update toolkit itself
claude-toolkit update
```

## Management Scripts

The toolkit provides five main management scripts:

### `claude-toolkit.sh` - Core Infrastructure
Manages the toolkit's core infrastructure, shell integration, and self-updates.

**Initial installation:**
```bash
./scripts/claude-toolkit.sh install     # Install toolkit infrastructure
```

**Normal usage (after installation):**
```bash
claude-toolkit update      # Update from remote repository
claude-toolkit uninstall   # Remove toolkit infrastructure
claude-toolkit validate    # Validate installation
```

### `claude-code.sh` - Claude Code Management
Handles Claude Code installations, version switching, and Node.js management.

**Normal usage:**
```bash
claude-code install                 # Install latest Claude Code
claude-code install --version 1.2.3 # Install specific version
claude-code list                    # List available versions
claude-code use --version 1.2.3     # Switch to installed version
```

### `claude-slash.sh` - Slash Commands Management
Manages slash commands from multiple sources while preserving user-created commands.

**Normal usage:**
```bash
claude-slash install                    # Install from all configured sources
claude-slash install --source claude-toolkit  # Install from specific source
claude-slash list                       # List all commands
claude-slash list --source user         # List only user commands
claude-slash reinstall                  # Update commands from all sources
claude-slash uninstall --source claude-toolkit  # Remove commands from specific source
```

### `claude-agents.sh` - Subagents Management
Manages subagents from multiple sources while preserving user-created subagents.

**Normal usage:**
```bash
claude-agents install                   # Install from all configured sources
claude-agents install --source claude-toolkit  # Install from specific source
claude-agents list                      # List all subagents
claude-agents list --source user        # List only user subagents
claude-agents reinstall                 # Update subagents from all sources
claude-agents uninstall --source claude-toolkit  # Remove subagents from specific source
```

### `claude-template-sources.sh` - Template Sources Management
Manages template source repositories (git repositories containing slash commands and subagents). See **[Template Sources Management](docs/claude-template-sources/index.md)** for detailed usage.

**Normal usage:**
```bash
claude-template-sources add team-alpha git@github.com:myorg/commands.git  # Add source
claude-template-sources list            # List configured sources
claude-template-sources remove team-alpha  # Remove source configuration
```

## Verification

Verify everything is working:
```bash
claude --version && claude-code list --mode installed
```

## Documentation

- **[Installation Guide](docs/installation.md)** - Installation instructions, troubleshooting, and authentication setup
- **[Architecture](docs/architecture.md)** - System design and component relationships
- **[Claude Code Management](docs/claude-code/index.md)** - Detailed claude-code.sh usage
- **[Slash Commands Management](docs/claude-slash/index.md)** - Detailed claude-slash.sh usage
- **[Subagents Management](docs/claude-agents/index.md)** - Detailed claude-agents.sh usage
- **[Template Sources Management](docs/claude-template-sources/index.md)** - Detailed claude-template-sources.sh usage
- **[Complete User Guide](docs/index.md)** - Advanced usage, customization, and integration examples

## Contributing

We welcome contributions:

1. **New Commands**: Add slash commands for common development tasks
2. **Bug Fixes**: Report and fix issues with existing tools  
3. **Testing**: Help improve test coverage and reliability

```bash
# Development setup (initial installation)
git clone git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git
cd claude-toolkit
./scripts/claude-toolkit.sh install
./tests/run-tests.sh
```

## Support

- **Slack**: [#insights-platform-team](https://apple.enterprise.slack.com/archives/C021R2PFEJU)
- **Issues**: Report bugs and request features in the repository

### Filing GitHub Issues

When reporting issues, please include:
- **Environment**: OS, shell type, Claude Code version (`claude --version`)
- **Steps to reproduce**: Clear, numbered steps
- **Expected vs actual behavior**: What should happen vs what actually happens
- **Error messages**: Full error output if applicable

## External Resources

- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Slash Commands Guide](https://docs.anthropic.com/en/docs/claude-code/slash-commands)

## License

Apple Internal
