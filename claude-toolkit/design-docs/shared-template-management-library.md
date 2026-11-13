# Shared Template Management Library

## Overview

This design document analyzes the reusable components in `scripts/claude-slash.sh` and proposes a shared library architecture for managing both slash commands and subagents. Both subsystems deal with similarly structured Markdown files containing prompt templates with YAML frontmatter, sourced from git repositories.

## Analysis of Reusable Components

### 1. Source Configuration Management
**Location**: Lines 27-210 in `claude-slash.sh`

**Reusable Functions**:
- `get_sources_config_dir()` ✅ Already generic
- `get_sources_config_file()` ✅ Already generic  
- `get_sources_cache_dir()` ✅ Already generic
- `ensure_sources_config()` ✅ Already generic
- `read_sources_config()` ✅ Already generic
- `write_template_sources_config()` ✅ Already generic
- `template_source_exists()` ✅ Already generic
- `get_template_source_url()` ✅ Already generic
- `add_template_source_to_config()` ✅ Already generic
- `remove_template_source_from_config()` ✅ Already generic

**Generalization Strategy**: These functions are already generic and can be moved to the shared library as-is.

### 2. Source List Processing
**Location**: Lines 212-340 in `claude-slash.sh`

**Reusable Functions**:
- `expand_template_source_list()` ✅ Already generic
- `expand_template_source_list_for_uninstall()` ✅ Already generic

**Generalization Strategy**: Already generic, can be moved as-is.

### 3. Validation Functions  
**Location**: Lines 71-108 in `claude-slash.sh`

**Reusable Functions**:
- `validate_source_name()` ✅ Already generic
- `validate_git_url()` ✅ Already generic

**Generalization Strategy**: Already generic, can be moved as-is.

### 4. Repository Management
**Location**: Lines 52-583 in `claude-slash.sh`

**Reusable Functions**:
- `calculate_repo_hash()` ✅ Already generic
- `get_cached_template_repository_dir()` ✅ Already generic
- `clone_or_update_repository()` ✅ Already generic
- `clone_or_update_template_source_repositories()` ✅ Already generic

**Generalization Strategy**: Already generic, can be moved as-is.

### 5. Template File Discovery and Processing
**Location**: Lines 413-496 in `claude-slash.sh`

**Functions Requiring Generalization**:
- `get_template_files()` → `get_template_files()`
- `get_template_file_source()` → `get_template_file_source()`  
- `filter_template_files_by_source()` → `filter_template_files_by_source()`

**Generalization Strategy**: 
- Rename functions to use "template" instead of "command"
- All logic remains the same (scanning for .md files, extracting YAML frontmatter)

### 6. Installation Directory Management
**Location**: Lines 32-50, 342-411 in `claude-slash.sh`

**Functions Requiring Parameterization**:
- `get_claude_commands_dir()` → `get_template_install_dir(template_type)`
- `validate_template_install_directory_permissions()` ✅ Already generic
- `create_template_install_directory()` ✅ Already generic

**Generalization Strategy**:
- Create `get_template_install_dir(template_type)` where `template_type` is "commands" or "agents"
- Returns `~/.claude/commands/` or `~/.claude/agents/` respectively

### 7. File Naming and Resolution
**Location**: Lines 498-537 in `claude-slash.sh`

**Functions Requiring Generalization**:
- `generate_stable_template_file_name()` → `generate_stable_template_file_name()`
- `resolve_toolkit_command_file()` → `resolve_toolkit_template_file()`

**Generalization Strategy**: 
- Rename to use "template" terminology
- Logic remains identical (stable naming with source suffix)

### 8. Repository Source Discovery
**Location**: Lines 585-603 in `claude-slash.sh`

**Functions Requiring Parameterization**:
- `find_template_files_in_sources()` → `find_template_files_in_sources(subdirectory)`

**Generalization Strategy**:
- Add `subdirectory` parameter (e.g., "slash-commands" or "agents")
- Currently hardcoded as `"$repo_dir/slash-commands"`

### 9. Installation Pipeline
**Location**: Lines 605-831 in `claude-slash.sh`

**Functions Requiring Light Refactoring**:
- `produce_install_info()` ⚠️ Mostly generic, some terminology updates needed
- `execute_install()` ⚠️ Mostly generic, some terminology updates needed  
- `execute_reinstall()` ⚠️ Mostly generic, some terminology updates needed
- `copy_file()` ✅ Already generic

**Generalization Strategy**:
- Update variable names and error messages to use "template" terminology
- Core logic for checksum comparison, conflict resolution remains identical

### 10. Uninstallation Pipeline
**Location**: Lines 983-1090 in `claude-slash.sh`

**Functions Requiring Light Refactoring**:
- `find_template_files_to_uninstall()` → `find_template_files_to_uninstall()`
- `validate_template_files_before_uninstall()` → `validate_template_files_before_uninstall()`
- `execute_uninstall()` → `uninstall_template_files()`

**Generalization Strategy**:
- Rename functions and update terminology in messages
- Core logic remains identical

### 11. Listing and Information
**Location**: Lines 1191-1311 in `claude-slash.sh`

**Functions Requiring Light Refactoring**:
- `emit_commands_info()` → `emit_templates_info()`
- `report_listed_command_files()` → `report_listed_template_files()`

**Generalization Strategy**:
- Update terminology in output messages
- Core information gathering logic remains identical

### 12. Reporting Functions
**Location**: Lines 833-895, 1052-1090 in `claude-slash.sh`

**Functions Requiring Light Refactoring**:
- `report_installed_template_files()` → `report_installed_template_files()`
- `report_uninstalled_template_files()` → `report_uninstalled_template_files()`

**Generalization Strategy**:
- Update terminology in success/error messages
- Add template type parameter for context-appropriate messaging

### 13. High-level Command Functions
**Location**: Lines 1313-1464 in `claude-slash.sh`

**Functions Already Generic**:
- `add_template_source()` ✅ Already generic
- `remove_template_source()` ✅ Already generic
- `list_template_sources()` ✅ Already generic

## Proposed Library Structure

### New Library File: `scripts/template-management.sh`

```bash
#!/bin/bash

# Template Management Library
# Shared functions for managing prompt templates (slash commands and subagents)

# Source the base library
source "$(dirname "${BASH_SOURCE[0]}")/library.sh"

# Template type constants
TEMPLATE_TYPE_COMMANDS="commands"
TEMPLATE_TYPE_AGENTS="agents"

# Configuration and directory functions
get_template_install_dir() {
    local template_type="$1"
    case "$template_type" in
        "$TEMPLATE_TYPE_COMMANDS")
            printf '%s/.claude/commands' "$(get_xdg_home)"
            ;;
        "$TEMPLATE_TYPE_AGENTS")
            printf '%s/.claude/agents' "$(get_xdg_home)"
            ;;
        *)
            log_error "Invalid template type: $template_type"
            return 1
            ;;
    esac
}

get_template_source_subdirectory() {
    local template_type="$1"
    case "$template_type" in
        "$TEMPLATE_TYPE_COMMANDS")
            echo "slash-commands"
            ;;
        "$TEMPLATE_TYPE_AGENTS")
            echo "agents"
            ;;
        *)
            log_error "Invalid template type: $template_type"
            return 1
            ;;
    esac
}

# All the generalized functions from analysis above...
```

### Updated File Locations

**Rename existing configuration**:
- `~/.config/claude-slash/sources.csv` → `~/.config/claude-templates/sources.csv`

**Update directory structure**:
- Cache remains in `~/.cache/slash-commands/` (repository cache is shared)
- Config moves to `~/.config/claude-templates/`

## Implementation Strategy

### Phase 1: Create Shared Library
1. Create `scripts/template-management.sh`
2. Move generic functions from `claude-slash.sh`
3. Implement parameterized functions for template-specific behavior

### Phase 2: Refactor claude-slash.sh
1. Update `claude-slash.sh` to use shared library
2. Update configuration paths
3. Test compatibility with existing installations

### Phase 3: Implement claude-subagents.sh
1. Create `claude-subagents.sh` using shared library
2. Implement subagent-specific functionality
3. Add comprehensive testing

## Key Benefits

1. **Code Reuse**: ~80% of functionality shared between subsystems
2. **Consistency**: Identical CLI interface and behavior patterns
3. **Maintainability**: Bug fixes and improvements benefit both subsystems
4. **Extensibility**: Easy to add new template types in the future

## Risk Mitigation

1. **Testing**: Comprehensive test coverage for shared library
2. **Clean Implementation**: No legacy compatibility burden

## Conclusion

The analysis reveals significant overlap between slash command and subagent management requirements. By creating a shared template management library, we can achieve substantial code reuse while maintaining clean separation of concerns. The proposed architecture minimizes code duplication and provides a solid foundation for future template management features.
