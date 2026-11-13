# CLAUDE.md

This file provides comprehensive guidance for Claude Code (AI assistant) when working with code in this repository.

## Project Overview

This is a Claude Toolkit repository containing reusable components for enhancing Claude Code workflows at Apple. The repository focuses on providing standardized slash commands and CLAUDE.md snippets that can be shared across projects.

For detailed human-facing project description, refer to @README.md.

**Self-Demonstrating Repository**: The slash commands defined in `slash-commands/` are directly available for use in this repository via the symbolic link at `.claude/commands/`.

## Repository Structure

- **`slash-commands/`** - Custom slash commands for common development tasks
- **`scripts/`** - Installation and setup scripts
- **`tests/`** - Test framework and test suites for validating setup scripts
- **`docs/`** - User-facing documentation
- **`external-docs/`** - Anthropic documentation copies for reference
- **`.claude/settings.local.json`** - Local Claude Code configuration
- **`.claude/commands/`** - Symbolic link to `slash-commands/` (makes commands available locally)

## Slash Command Authoring Reference

For proper slash command authoring, consult these authoritative references in `external-docs/`:

1. **`claude-overview.md`** - Design philosophy and effective command patterns
2. **`claude-cli-reference.md`** - CLI context and integration patterns
3. **`claude-slash-commands.md`** - Essential reference for command structure, YAML frontmatter, dynamic content features (`$ARGUMENTS`, `!` for bash, `@` for file references), and scoping rules
4. **`claude-code-allowed-tools.md`** - Critical for `allowed-tools` syntax, complete tool list, permission requirements, and filter syntax (e.g., `Bash(git add:*)`)

For command security standards and quality requirements, refer to @slash-commands/add-command.md which contains detailed guidance on creating secure and well-formed commands.

## Testing Framework

The repository includes a comprehensive testing framework designed for safe validation of installation scripts and functionality. For detailed information about writing, running, and debugging tests, use the test-writer-debugger agent when working with tests in the `@tests/` directory.
