#!/bin/bash
# test-claude-slash-list.sh - Tests claude-slash.sh list functionality with multiple sources
# 
# Purpose: Test scripts/claude-slash.sh list functionality according to multiple sources specification
# Dependencies: None (creates own test command files)
# Approach: Create comprehensive test scenarios for all source types, filtering options, and output formats

source "$(dirname "$0")/../utils/test-harness.sh"

export PORCELAIN=true

test_list_all_sources_default() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/commands"
        
        # Create claude-toolkit source commands
        cat > "$HOME/.claude/commands/toolkit-alpha.md" << 'EOF'
---
description: First claude-toolkit command
source: claude-toolkit
argument-hint: <argument>
---

# Alpha Toolkit Command
This is a claude-toolkit command.
EOF
        
        cat > "$HOME/.claude/commands/toolkit-beta.md" << 'EOF'
---
description: Second claude-toolkit command
source: claude-toolkit
---

# Beta Toolkit Command
This is another claude-toolkit command.
EOF
        
        # Create user commands (no source field)
        cat > "$HOME/.claude/commands/user-gamma.md" << 'EOF'
---
description: First user command
argument-hint: <path>
---

# Gamma User Command
This is a user command.
EOF
        
        cat > "$HOME/.claude/commands/user-delta.md" << 'EOF'
---
description: Second user command
---

# Delta User Command
This is another user command.
EOF
        
        # Create team-alpha source commands
        cat > "$HOME/.claude/commands/deploy.md" << 'EOF'
---
description: Deploy application with safety checks
source: team-alpha
argument-hint: <environment> [--dry-run]
---

# Deploy Command
Deploy application to specified environment.
EOF
        
        # Create team-beta source command
        cat > "$HOME/.claude/commands/security-scan.md" << 'EOF'
---
description: Run security analysis
source: team-beta
argument-hint: [--full]
---

# Security Scan Command
Perform security analysis on codebase.
EOF
        
        local list_output
        list_output=$(assert_command_succeeds "List all sources should succeed" -- ./scripts/claude-slash.sh list)
        
        # Verify all commands appear in porcelain format: file_path<TAB>file_name<TAB>source_name<TAB>file_size<TAB>mod_date<TAB>description
        assert_contains $'\ttoolkit-alpha.md\tclaude-toolkit\t' "$list_output" \
            "Should show claude-toolkit command with correct source"
        assert_contains $'\ttoolkit-beta.md\tclaude-toolkit\t' "$list_output" \
            "Should show second claude-toolkit command with correct source"
        assert_contains $'\tuser-gamma.md\tuser\t' "$list_output" \
            "Should show user command with user source"
        assert_contains $'\tuser-delta.md\tuser\t' "$list_output" \
            "Should show second user command with user source"
        assert_contains $'\tdeploy.md\tteam-alpha\t' "$list_output" \
            "Should show team-alpha command with correct source"
        assert_contains $'\tsecurity-scan.md\tteam-beta\t' "$list_output" \
            "Should show team-beta command with correct source"
        
        # Verify descriptions are included
        assert_contains "First claude-toolkit command" "$list_output" \
            "Should include claude-toolkit command description"
        assert_contains "First user command" "$list_output" \
            "Should include user command description"
        assert_contains "Deploy application with safety checks" "$list_output" \
            "Should include team-alpha command description"
        assert_contains "Run security analysis" "$list_output" \
            "Should include team-beta command description"
        
        # Verify we have exactly 6 lines of output (one per command)
        local line_count=$(echo "$list_output" | wc -l | tr -d ' ')
        assert_equals "6" "$line_count" "Should have exactly 6 lines of porcelain output"
    )
}

test_list_claude_toolkit_source_only() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/commands"
        
        # Create claude-toolkit source commands
        cat > "$HOME/.claude/commands/add-command.md" << 'EOF'
---
description: Create a new Claude Code slash command
source: claude-toolkit
argument-hint: scope command-name [options]
---

# Add Command Helper
Create a new slash command.
EOF
        
        cat > "$HOME/.claude/commands/smart-commit.md" << 'EOF'
---
description: Generate intelligent commit messages
source: claude-toolkit
argument-hint: [--amend]
---

# Smart Commit
Generate commit messages from changes.
EOF
        
        # Create user commands (should be filtered out)
        cat > "$HOME/.claude/commands/my-helper.md" << 'EOF'
---
description: Personal helper command
---

# My Helper
Personal utility command.
EOF
        
        # Create team-alpha commands (should be filtered out)
        cat > "$HOME/.claude/commands/deploy.md" << 'EOF'
---
description: Deploy application
source: team-alpha
---

# Deploy Command
Deploy to environment.
EOF
        
        local toolkit_output
        toolkit_output=$(assert_command_succeeds "List claude-toolkit source only should succeed" -- ./scripts/claude-slash.sh list --source claude-toolkit)
        
        # Should only contain claude-toolkit commands
        assert_contains $'\tadd-command.md\tclaude-toolkit\t' "$toolkit_output" \
            "Should show add-command from claude-toolkit source"
        assert_contains $'\tsmart-commit.md\tclaude-toolkit\t' "$toolkit_output" \
            "Should show smart-commit from claude-toolkit source"
        
        # Should not contain user or other source commands
        assert_not_contains "my-helper.md" "$toolkit_output" \
            "Should not show user commands in claude-toolkit filter"
        assert_not_contains "deploy.md" "$toolkit_output" \
            "Should not show team-alpha commands in claude-toolkit filter"
        
        # Verify descriptions are included
        assert_contains "Create a new Claude Code slash command" "$toolkit_output" \
            "Should include add-command description"
        assert_contains "Generate intelligent commit messages" "$toolkit_output" \
            "Should include smart-commit description"
        
        # Verify we have exactly 2 lines of output (claude-toolkit commands only)
        local line_count=$(echo "$toolkit_output" | wc -l | tr -d ' ')
        assert_equals "2" "$line_count" "Should have exactly 2 lines of porcelain output"
    )
}

test_list_user_source_only() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/commands"
        
        # Create claude-toolkit commands (should be filtered out)
        cat > "$HOME/.claude/commands/add-command.md" << 'EOF'
---
description: Toolkit command (should be filtered out)
source: claude-toolkit
---

# Add Command
Toolkit command.
EOF
        
        # Create team-alpha commands (should be filtered out)
        cat > "$HOME/.claude/commands/deploy.md" << 'EOF'
---
description: Team command (should be filtered out)
source: team-alpha
---

# Deploy Command
Team command.
EOF
        
        # Create user commands (no source field)
        cat > "$HOME/.claude/commands/my-script.md" << 'EOF'
---
description: Personal automation script
argument-hint: <action>
---

# My Script
Personal automation utility.
EOF
        
        cat > "$HOME/.claude/commands/project-helper.md" << 'EOF'
---
description: Project-specific helper
---

# Project Helper
Project-specific utilities.
EOF
        
        local user_output
        user_output=$(assert_command_succeeds "List user source only should succeed" -- ./scripts/claude-slash.sh list --source user)
        
        # Should only contain user commands (no source field)
        assert_contains $'\tmy-script.md\tuser\t' "$user_output" \
            "Should show my-script as user command"
        assert_contains $'\tproject-helper.md\tuser\t' "$user_output" \
            "Should show project-helper as user command"
        
        # Should not contain source commands
        assert_not_contains "add-command.md" "$user_output" \
            "Should not show claude-toolkit commands in user filter"
        assert_not_contains "deploy.md" "$user_output" \
            "Should not show team-alpha commands in user filter"
        
        # Verify descriptions are included
        assert_contains "Personal automation script" "$user_output" \
            "Should include my-script description"
        assert_contains "Project-specific helper" "$user_output" \
            "Should include project-helper description"
        
        # Verify we have exactly 2 lines of output (user commands only)
        local line_count=$(echo "$user_output" | wc -l | tr -d ' ')
        assert_equals "2" "$line_count" "Should have exactly 2 lines of porcelain output"
    )
}

test_list_all_source_explicit() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/commands"
        
        # Create mixed source commands
        cat > "$HOME/.claude/commands/toolkit-cmd.md" << 'EOF'
---
description: Claude toolkit command
source: claude-toolkit
---

# Toolkit Command
Toolkit command.
EOF
        
        cat > "$HOME/.claude/commands/user-cmd.md" << 'EOF'
---
description: User command
---

# User Command
User command.
EOF
        
        cat > "$HOME/.claude/commands/team-cmd.md" << 'EOF'
---
description: Team command
source: team-alpha
---

# Team Command
Team command.
EOF
        
        local all_output
        all_output=$(assert_command_succeeds "List --source all should succeed" -- ./scripts/claude-slash.sh list --source all)
        
        # Should show all commands from all sources
        assert_contains $'\ttoolkit-cmd.md\tclaude-toolkit\t' "$all_output" \
            "Should show claude-toolkit command with --source all"
        assert_contains $'\tuser-cmd.md\tuser\t' "$all_output" \
            "Should show user command with --source all"
        assert_contains $'\tteam-cmd.md\tteam-alpha\t' "$all_output" \
            "Should show team-alpha command with --source all"
        
        # Verify we have exactly 3 lines of output
        local line_count=$(echo "$all_output" | wc -l | tr -d ' ')
        assert_equals "3" "$line_count" "Should have exactly 3 lines with --source all"
    )
}

test_list_custom_source_only() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/commands"
        
        # Create team-alpha source commands
        cat > "$HOME/.claude/commands/deploy.md" << 'EOF'
---
description: Deploy application with safety checks
source: team-alpha
argument-hint: <environment> [--dry-run]
allowed-tools: Bash(kubectl:*)
---

# Deploy Command
Deploy application to specified environment.
EOF
        
        cat > "$HOME/.claude/commands/test-runner.md" << 'EOF'
---
description: Run comprehensive test suites
source: team-alpha
argument-hint: [--coverage]
---

# Test Runner
Execute test suites with reporting.
EOF
        
        # Create other source commands (should be filtered out)
        cat > "$HOME/.claude/commands/toolkit-cmd.md" << 'EOF'
---
description: Toolkit command (filtered out)
source: claude-toolkit
---

# Toolkit Command
EOF
        
        cat > "$HOME/.claude/commands/user-cmd.md" << 'EOF'
---
description: User command (filtered out)
---

# User Command
EOF
        
        cat > "$HOME/.claude/commands/other-team-cmd.md" << 'EOF'
---
description: Other team command (filtered out)
source: team-beta
---

# Other Team Command
EOF
        
        local team_alpha_output
        team_alpha_output=$(assert_command_succeeds "List team-alpha source only should succeed" -- ./scripts/claude-slash.sh list --source team-alpha)
        
        # Should only contain team-alpha commands
        assert_contains $'\tdeploy.md\tteam-alpha\t' "$team_alpha_output" \
            "Should show deploy command from team-alpha source"
        assert_contains $'\ttest-runner.md\tteam-alpha\t' "$team_alpha_output" \
            "Should show test-runner command from team-alpha source"
        
        # Should not contain other source commands
        assert_not_contains "toolkit-cmd.md" "$team_alpha_output" \
            "Should not show claude-toolkit commands in team-alpha filter"
        assert_not_contains "user-cmd.md" "$team_alpha_output" \
            "Should not show user commands in team-alpha filter"
        assert_not_contains "other-team-cmd.md" "$team_alpha_output" \
            "Should not show team-beta commands in team-alpha filter"
        
        # Verify descriptions are included
        assert_contains "Deploy application with safety checks" "$team_alpha_output" \
            "Should include deploy command description"
        assert_contains "Run comprehensive test suites" "$team_alpha_output" \
            "Should include test-runner command description"
        
        # Verify we have exactly 2 lines of output
        local line_count=$(echo "$team_alpha_output" | wc -l | tr -d ' ')
        assert_equals "2" "$line_count" "Should have exactly 2 lines for team-alpha source"
    )
}

test_list_comma_separated_sources() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/commands"
        
        # Create commands from multiple sources
        cat > "$HOME/.claude/commands/toolkit-cmd.md" << 'EOF'
---
description: Claude toolkit command
source: claude-toolkit
---

# Toolkit Command
Toolkit functionality.
EOF
        
        cat > "$HOME/.claude/commands/user-cmd.md" << 'EOF'
---
description: User-created command
---

# User Command
User functionality.
EOF
        
        cat > "$HOME/.claude/commands/team-alpha-cmd.md" << 'EOF'
---
description: Team alpha command
source: team-alpha
---

# Team Alpha Command
Team alpha functionality.
EOF
        
        cat > "$HOME/.claude/commands/team-beta-cmd.md" << 'EOF'
---
description: Team beta command
source: team-beta
---

# Team Beta Command
Team beta functionality.
EOF
        
        # Test comma-separated source filtering: user,claude-toolkit
        local user_toolkit_output
        user_toolkit_output=$(assert_command_succeeds "List user,claude-toolkit sources should succeed" -- ./scripts/claude-slash.sh list --source user,claude-toolkit)
        
        # Should contain user and claude-toolkit commands
        assert_contains $'\ttoolkit-cmd.md\tclaude-toolkit\t' "$user_toolkit_output" \
            "Should show claude-toolkit command in user,claude-toolkit filter"
        assert_contains $'\tuser-cmd.md\tuser\t' "$user_toolkit_output" \
            "Should show user command in user,claude-toolkit filter"
        
        # Should not contain team commands
        assert_not_contains "team-alpha-cmd.md" "$user_toolkit_output" \
            "Should not show team-alpha commands in user,claude-toolkit filter"
        assert_not_contains "team-beta-cmd.md" "$user_toolkit_output" \
            "Should not show team-beta commands in user,claude-toolkit filter"
        
        # Test comma-separated source filtering: team-alpha,team-beta
        local teams_output
        teams_output=$(assert_command_succeeds "List team-alpha,team-beta sources should succeed" -- ./scripts/claude-slash.sh list --source team-alpha,team-beta)
        
        # Should contain both team commands
        assert_contains $'\tteam-alpha-cmd.md\tteam-alpha\t' "$teams_output" \
            "Should show team-alpha command in team-alpha,team-beta filter"
        assert_contains $'\tteam-beta-cmd.md\tteam-beta\t' "$teams_output" \
            "Should show team-beta command in team-alpha,team-beta filter"
        
        # Should not contain user or toolkit commands
        assert_not_contains "toolkit-cmd.md" "$teams_output" \
            "Should not show claude-toolkit commands in team-alpha,team-beta filter"
        assert_not_contains "user-cmd.md" "$teams_output" \
            "Should not show user commands in team-alpha,team-beta filter"
        
        # Verify line counts
        local user_toolkit_count=$(echo "$user_toolkit_output" | wc -l | tr -d ' ')
        assert_equals "2" "$user_toolkit_count" "Should have exactly 2 lines for user,claude-toolkit filter"
        
        local teams_count=$(echo "$teams_output" | wc -l | tr -d ' ')
        assert_equals "2" "$teams_count" "Should have exactly 2 lines for team-alpha,team-beta filter"
    )
}

test_list_empty_environment_non_porcelain() {
    (
        create_sandbox
        export PORCELAIN=false
        
        rm -rf "$HOME/.claude/commands"
        
        # Test empty environment in non-porcelain mode
        local empty_output
        empty_output=$(assert_command_succeeds "List should succeed on empty environment (non-porcelain)" -- ./scripts/claude-slash.sh list 2>&1)
        
        # Should not contain "Found" messages when no files exist
        assert_not_contains "Found" "$empty_output" \
            "Should not show 'Found' message when no commands exist in non-porcelain mode"
        
        # Test filtered outputs in non-porcelain mode as well
        local empty_toolkit_output
        empty_toolkit_output=$(assert_command_succeeds "Claude-toolkit source should succeed (non-porcelain)" -- ./scripts/claude-slash.sh list --source claude-toolkit 2>&1)
        assert_not_contains "Found" "$empty_toolkit_output" \
            "Should not show 'Found' message for empty claude-toolkit source in non-porcelain mode"
            
        local empty_user_output
        empty_user_output=$(assert_command_succeeds "User source should succeed (non-porcelain)" -- ./scripts/claude-slash.sh list --source user 2>&1)
        assert_not_contains "Found" "$empty_user_output" \
            "Should not show 'Found' message for empty user source in non-porcelain mode"
            
        # Test nonexistent source in non-porcelain mode
        local nonexistent_output
        nonexistent_output=$(assert_command_succeeds "Nonexistent source should succeed (non-porcelain)" -- ./scripts/claude-slash.sh list --source asdfasdf 2>&1)
        assert_not_contains "Found" "$nonexistent_output" \
            "Should not show 'Found' message for nonexistent source in non-porcelain mode"
    )
}

test_list_empty_environment() {
    (
        create_sandbox
        
        rm -rf "$HOME/.claude/commands"
        
        local empty_output
        empty_output=$(assert_command_succeeds "List should succeed on empty environment" -- ./scripts/claude-slash.sh list)
        
        # In porcelain mode, empty environment should produce no output
        assert_equals "" "$empty_output" \
            "Should produce empty output in porcelain mode when no commands exist"
        
        # Test filtered outputs as well
        local empty_toolkit_output
        empty_toolkit_output=$(assert_command_succeeds "Claude-toolkit source should succeed" -- ./scripts/claude-slash.sh list --source claude-toolkit)
        local empty_user_output
        empty_user_output=$(assert_command_succeeds "User source should succeed" -- ./scripts/claude-slash.sh list --source user)
        local empty_all_output
        empty_all_output=$(assert_command_succeeds "All sources should succeed" -- ./scripts/claude-slash.sh list --source all)
        
        assert_equals "" "$empty_toolkit_output" \
            "Should produce empty output for claude-toolkit source when no commands exist"
        assert_equals "" "$empty_user_output" \
            "Should produce empty output for user source when no commands exist"
        assert_equals "" "$empty_all_output" \
            "Should produce empty output for all sources when no commands exist"
    )
}

test_list_non_porcelain_format() {
    (
        create_sandbox
        export PORCELAIN=false
        
        mkdir -p "$HOME/.claude/commands"
        
        # Create mixed source commands
        cat > "$HOME/.claude/commands/toolkit-cmd.md" << 'EOF'
---
description: Claude toolkit command
source: claude-toolkit
---

# Toolkit Command
Toolkit functionality.
EOF
        
        cat > "$HOME/.claude/commands/user-cmd.md" << 'EOF'
---
description: User command
---

# User Command
User functionality.
EOF
        
        local human_output
        human_output=$(assert_command_succeeds "List in human-readable format should succeed" -- ./scripts/claude-slash.sh list)
        
        # Should contain human-readable formatting (not porcelain)
        assert_contains "toolkit-cmd.md" "$human_output" \
            "Should show toolkit command filename in human format"
        assert_contains "user-cmd.md" "$human_output" \
            "Should show user command filename in human format"
        
        # Should contain source indicators in human format
        assert_contains "(claude-toolkit)" "$human_output" \
            "Should show (claude-toolkit) indicator in human format"
        assert_contains "(user)" "$human_output" \
            "Should show (user) indicator in human format"
        
        # Should NOT contain tab-separated format
        assert_not_contains $'\ttoolkit-cmd.md\tclaude-toolkit\t' "$human_output" \
            "Should not show porcelain format in human-readable mode"
        assert_not_contains $'\tuser-cmd.md\tuser\t' "$human_output" \
            "Should not show porcelain format in human-readable mode"
    )
}

test_list_detailed_format() {
    (
        create_sandbox
        export PORCELAIN=false
        
        mkdir -p "$HOME/.claude/commands"
        
        # Create commands with rich metadata
        cat > "$HOME/.claude/commands/detailed-cmd.md" << 'EOF'
---
description: Command with rich metadata for detailed format testing
source: claude-toolkit
argument-hint: <input> [--verbose]
allowed-tools: Read, Write, Bash
---

# Detailed Command
Command with comprehensive metadata for testing detailed format display.
EOF
        
        cat > "$HOME/.claude/commands/simple-user-cmd.md" << 'EOF'
---
description: Simple user command for format testing
---

# Simple User Command
Basic user command for testing.
EOF
        
        local detailed_output
        detailed_output=$(assert_command_succeeds "List with detailed format should succeed" -- ./scripts/claude-slash.sh list --format detailed)
        
        # Should contain detailed formatting elements
        assert_contains "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$detailed_output" \
            "Should show detailed format separator lines"
        assert_contains "File:" "$detailed_output" \
            "Should show File: label in detailed format"
        assert_contains "Origin:" "$detailed_output" \
            "Should show Origin: label in detailed format"
        assert_contains "Path:" "$detailed_output" \
            "Should show Path: label in detailed format"
        assert_contains "Size:" "$detailed_output" \
            "Should show Size: label in detailed format"
        assert_contains "Modified:" "$detailed_output" \
            "Should show Modified: label in detailed format"
        assert_contains "Description:" "$detailed_output" \
            "Should show Description: label in detailed format"
        
        # Should contain command information
        assert_contains "detailed-cmd.md" "$detailed_output" \
            "Should show detailed command filename"
        assert_contains "simple-user-cmd.md" "$detailed_output" \
            "Should show simple user command filename"
        assert_contains "claude-toolkit" "$detailed_output" \
            "Should show claude-toolkit source"
        assert_contains "user" "$detailed_output" \
            "Should show user source"
        
        # Should contain descriptions
        assert_contains "Command with rich metadata for detailed format testing" "$detailed_output" \
            "Should show detailed command description"
        assert_contains "Simple user command for format testing" "$detailed_output" \
            "Should show user command description"
    )
}

test_list_compact_format() {
    (
        create_sandbox
        export PORCELAIN=false
        
        mkdir -p "$HOME/.claude/commands"
        
        # Create test commands
        cat > "$HOME/.claude/commands/compact-cmd.md" << 'EOF'
---
description: Command for compact format testing
source: claude-toolkit
---

# Compact Command
EOF
        
        cat > "$HOME/.claude/commands/user-compact.md" << 'EOF'
---
description: User command for compact format testing
---

# User Compact Command
EOF
        
        local compact_output
        compact_output=$(assert_command_succeeds "List with compact format should succeed" -- ./scripts/claude-slash.sh list --format compact)
        
        # Should contain compact formatting (command name and source)
        assert_contains "compact-cmd.md (claude-toolkit)" "$compact_output" \
            "Should show compact format for claude-toolkit command"
        assert_contains "user-compact.md (user)" "$compact_output" \
            "Should show compact format for user command"
        
        # Should NOT contain detailed format elements
        assert_not_contains "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$compact_output" \
            "Should not show detailed format separator lines in compact mode"
        assert_not_contains "File:" "$compact_output" \
            "Should not show File: label in compact format"
        assert_not_contains "Origin:" "$compact_output" \
            "Should not show Origin: label in compact format"
    )
}

test_list_nonexistent_source() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/commands"
        
        # Create some commands
        cat > "$HOME/.claude/commands/user-cmd.md" << 'EOF'
---
description: User command
---

# User Command
User functionality.
EOF
        
        # Test filtering by nonexistent source
        local nonexistent_output
        nonexistent_output=$(assert_command_succeeds "List nonexistent source should succeed with empty output" -- ./scripts/claude-slash.sh list --source nonexistent-source)
        
        # Should produce empty output for nonexistent source
        assert_equals "" "$nonexistent_output" \
            "Should produce empty output for nonexistent source filter"
    )
}

test_list_porcelain_output_format() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/commands"
        
        # Create command with known content for format verification
        cat > "$HOME/.claude/commands/format-test.md" << 'EOF'
---
description: Command for testing porcelain output format
source: claude-toolkit
argument-hint: <input>
---

# Format Test Command
This command tests the porcelain output format.
EOF
        
        local porcelain_output
        porcelain_output=$(assert_command_succeeds "Porcelain format output should succeed" -- ./scripts/claude-slash.sh list --source claude-toolkit)
        
        # Porcelain format should be: file_path<TAB>file_name<TAB>source_name<TAB>file_size<TAB>mod_date<TAB>description
        # Verify the structure by counting tabs and checking field positions
        local line_count=$(echo "$porcelain_output" | wc -l | tr -d ' ')
        assert_equals "1" "$line_count" "Should have exactly 1 line of porcelain output"
        
        # Verify tab-separated format
        local tab_count=$(echo "$porcelain_output" | tr -cd '\t' | wc -c | tr -d ' ')
        assert_equals "5" "$tab_count" "Should have exactly 5 tabs (6 fields) in porcelain format"
        
        # Extract fields and verify content
        local file_path=$(echo "$porcelain_output" | cut -f1)
        local file_name=$(echo "$porcelain_output" | cut -f2)
        local source_name=$(echo "$porcelain_output" | cut -f3)
        local file_size=$(echo "$porcelain_output" | cut -f4)
        local mod_date=$(echo "$porcelain_output" | cut -f5)
        local description=$(echo "$porcelain_output" | cut -f6)
        
        assert_contains "format-test.md" "$file_path" "File path should contain filename"
        assert_equals "format-test.md" "$file_name" "File name field should be exact filename"
        assert_equals "claude-toolkit" "$source_name" "Source name should be claude-toolkit"
        assert_matches "^[0-9]+$" "$file_size" "File size should be numeric"
        assert_contains "Command for testing porcelain output format" "$description" "Description should match frontmatter"
    )
}

test_list_source_field_parsing() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/commands"
        
        # Test various source field formats
        cat > "$HOME/.claude/commands/source-standard.md" << 'EOF'
---
description: Standard source format
source: team-standard
---

# Standard Source
EOF
        
        cat > "$HOME/.claude/commands/source-spaces.md" << 'EOF'
---
description: Source format with spaces
source:   team-spaces   
---

# Source with Spaces
EOF
        
        cat > "$HOME/.claude/commands/source-hyphen.md" << 'EOF'
---
description: Source format with hyphens
source: team-with-hyphens
---

# Source with Hyphens
EOF
        
        cat > "$HOME/.claude/commands/source-underscore.md" << 'EOF'
---
description: Source format with underscores
source: team_with_underscores
---

# Source with Underscores
EOF
        
        cat > "$HOME/.claude/commands/no-source.md" << 'EOF'
---
description: Command with no source field
---

# No Source Command
EOF
        
        local all_output
        all_output=$(assert_command_succeeds "List all should handle various source formats" -- ./scripts/claude-slash.sh list)
        
        # Verify all source formats are parsed correctly
        assert_contains $'\tsource-standard.md\tteam-standard\t' "$all_output" \
            "Should parse standard source format correctly"
        assert_contains $'\tsource-spaces.md\tteam-spaces\t' "$all_output" \
            "Should parse source format with extra spaces correctly"
        assert_contains $'\tsource-hyphen.md\tteam-with-hyphens\t' "$all_output" \
            "Should parse source format with hyphens correctly"
        assert_contains $'\tsource-underscore.md\tteam_with_underscores\t' "$all_output" \
            "Should parse source format with underscores correctly"
        assert_contains $'\tno-source.md\tuser\t' "$all_output" \
            "Should default to user source when no source field present"
        
        # Test filtering works correctly for parsed sources
        local standard_output
        standard_output=$(assert_command_succeeds "Filter team-standard should work" -- ./scripts/claude-slash.sh list --source team-standard)
        assert_contains $'\tsource-standard.md\tteam-standard\t' "$standard_output" \
            "Should filter team-standard source correctly"
        
        local hyphen_output
        hyphen_output=$(assert_command_succeeds "Filter team-with-hyphens should work" -- ./scripts/claude-slash.sh list --source team-with-hyphens)
        assert_contains $'\tsource-hyphen.md\tteam-with-hyphens\t' "$hyphen_output" \
            "Should filter team-with-hyphens source correctly"
        
        local user_output
        user_output=$(assert_command_succeeds "Filter user should work" -- ./scripts/claude-slash.sh list --source user)
        assert_contains $'\tno-source.md\tuser\t' "$user_output" \
            "Should filter user commands (no source field) correctly"
    )
}

test_list_source_field_only_specification() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/commands"
        
        # Test commands with ONLY source field (no backward compatibility)
        cat > "$HOME/.claude/commands/claude-toolkit-source.md" << 'EOF'
---
description: Command with claude-toolkit source field
source: claude-toolkit
---

# Claude Toolkit Source Command
EOF
        
        cat > "$HOME/.claude/commands/custom-source.md" << 'EOF'
---
description: Command with custom source field
source: my-custom-source
---

# Custom Source Command
EOF
        
        cat > "$HOME/.claude/commands/no-source-defaults-user.md" << 'EOF'
---
description: Command with no source field defaults to user
---

# User Default Command
EOF
        
        local all_output
        all_output=$(assert_command_succeeds "List all sources should work with source-only specification" -- ./scripts/claude-slash.sh list)
        
        # Verify source field parsing
        assert_contains $'\tclaude-toolkit-source.md\tclaude-toolkit\t' "$all_output" \
            "Should identify claude-toolkit source from source field"
        assert_contains $'\tcustom-source.md\tmy-custom-source\t' "$all_output" \
            "Should identify custom source from source field"
        assert_contains $'\tno-source-defaults-user.md\tuser\t' "$all_output" \
            "Should default to user source when no source field present"
        
        # Test specific source filtering
        local toolkit_output
        toolkit_output=$(assert_command_succeeds "Filter claude-toolkit should work" -- ./scripts/claude-slash.sh list --source claude-toolkit)
        assert_contains $'\tclaude-toolkit-source.md\tclaude-toolkit\t' "$toolkit_output" \
            "Should filter claude-toolkit source correctly"
        assert_not_contains "custom-source.md" "$toolkit_output" \
            "Should not show custom source in claude-toolkit filter"
        assert_not_contains "no-source-defaults-user.md" "$toolkit_output" \
            "Should not show user command in claude-toolkit filter"
        
        local custom_output
        custom_output=$(assert_command_succeeds "Filter custom source should work" -- ./scripts/claude-slash.sh list --source my-custom-source)
        assert_contains $'\tcustom-source.md\tmy-custom-source\t' "$custom_output" \
            "Should filter custom source correctly"
        assert_not_contains "claude-toolkit-source.md" "$custom_output" \
            "Should not show claude-toolkit command in custom source filter"
        assert_not_contains "no-source-defaults-user.md" "$custom_output" \
            "Should not show user command in custom source filter"
        
        local user_output
        user_output=$(assert_command_succeeds "Filter user should work" -- ./scripts/claude-slash.sh list --source user)
        assert_contains $'\tno-source-defaults-user.md\tuser\t' "$user_output" \
            "Should filter user commands correctly"
        assert_not_contains "claude-toolkit-source.md" "$user_output" \
            "Should not show claude-toolkit command in user filter"
        assert_not_contains "custom-source.md" "$user_output" \
            "Should not show custom source command in user filter"
    )
}

test_list_error_cases() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/commands"
        
        # Test invalid source arguments (should fail with validation error)
        assert_command_fails "Empty source should fail with validation error" -- ./scripts/claude-slash.sh list --source "" 2>/dev/null
        
        # Test comma-separated with empty elements
        cat > "$HOME/.claude/commands/user-cmd.md" << 'EOF'
---
description: User command for comma testing
---

# User Command
EOF
        
        local comma_with_empty_output
        comma_with_empty_output=$(assert_command_succeeds "Comma with empty should work" -- ./scripts/claude-slash.sh list --source "user,,")
        assert_contains $'\tuser-cmd.md\tuser\t' "$comma_with_empty_output" \
            "Should handle comma-separated list with empty elements"
    )
}

# Register all test functions
register_tests \
    "test_list_all_sources_default" \
    "test_list_claude_toolkit_source_only" \
    "test_list_user_source_only" \
    "test_list_all_source_explicit" \
    "test_list_custom_source_only" \
    "test_list_comma_separated_sources" \
    "test_list_empty_environment" \
    "test_list_empty_environment_non_porcelain" \
    "test_list_non_porcelain_format" \
    "test_list_detailed_format" \
    "test_list_compact_format" \
    "test_list_nonexistent_source" \
    "test_list_porcelain_output_format" \
    "test_list_source_field_parsing" \
    "test_list_source_field_only_specification" \
    "test_list_error_cases"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-slash.sh list functionality with multiple sources" "$@"
fi
