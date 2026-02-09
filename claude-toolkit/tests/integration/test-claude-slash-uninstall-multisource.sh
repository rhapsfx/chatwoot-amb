#!/bin/bash
# test-claude-slash-uninstall-multisource.sh - Refactored multi-source tests
#
# Purpose: Test scripts/claude-slash.sh multi-source uninstall functionality

source "$(dirname "$0")/../utils/test-harness.sh"
source "$(dirname "$0")/../utils/file-utils.sh"

# Source claude-slash.sh to access its functions
source "$(dirname "$0")/../../scripts/claude-slash.sh"

# Enable debug mode for all tests to capture debug messages
export DEBUG=true

# Get toolkit command files dynamically
get_toolkit_command_files() {
    local commands_dir="$1"
    get_template_files "$commands_dir" | filter_template_files_by_source "claude-toolkit"
}

# Get user command files dynamically
get_user_command_files() {
    local commands_dir="$1"
    get_template_files "$commands_dir" | filter_template_files_by_source "user"
}

test_uninstall_source_user_rejection() {
    (
        create_sandbox

        # Create toolkit commands manually instead of relying on install
        mkdir -p "$HOME/.claude/commands"
        cat > "$HOME/.claude/commands/add-command.md" << 'EOF'
---
description: Create a new Claude Code slash command
source: claude-toolkit
---

# Add Command Helper

Mock toolkit command for testing.
EOF

        cat > "$HOME/.claude/commands/smart-commit.md" << 'EOF'
---
description: Generate intelligent commit messages
source: claude-toolkit
---

# Smart Commit

Mock toolkit command for testing.
EOF

        # Create user commands
        cat > "$HOME/.claude/commands/user-helper.md" << 'EOF'
---
description: User helper command that cannot be removed
---

# User Helper

This is a user-created command that should NOT be removable via --source user.
EOF

        cat > "$HOME/.claude/commands/personal-workflow.md" << 'EOF'
---
description: Personal workflow automation that cannot be removed
---

# Personal Workflow

User command for personal workflow automation that is protected.
EOF

        # Get dynamic command lists
        local initial_toolkit_files=($(get_toolkit_command_files "$HOME/.claude/commands"))
        local initial_user_files=($(get_user_command_files "$HOME/.claude/commands"))

        # Verify initial state
        assert_greater_than "${#initial_toolkit_files[@]}" "0" "Should have toolkit commands initially"
        assert_greater_than "${#initial_user_files[@]}" "0" "Should have user commands initially"

        # Store directory checksum to verify nothing changes
        local initial_directory_checksum=$(calculate_directory_checksum "$HOME/.claude/commands")

        # CRITICAL TEST: --source user should FAIL with error and change nothing
        local user_uninstall_output
        user_uninstall_output=$(assert_command_fails "Uninstall --source user should FAIL" -- ./scripts/claude-slash.sh uninstall --source user -y 2>&1)

        # Verify error messages
        assert_contains "Cannot uninstall user files" "$user_uninstall_output" \
            "Should show clear error about user command protection"

        # Verify NOTHING was changed - directory should have identical checksum
        local final_directory_checksum=$(calculate_directory_checksum "$HOME/.claude/commands")
        assert_equals "$initial_directory_checksum" "$final_directory_checksum" \
            "Directory should be completely unchanged after failed --source user operation"
    )
}

test_uninstall_source_all_commands() {
    (
        create_sandbox

        # Create toolkit commands manually instead of relying on install  
        mkdir -p "$HOME/.claude/commands"
        cat > "$HOME/.claude/commands/add-command.md" << 'EOF'
---
description: Create a new Claude Code slash command
source: claude-toolkit
---

# Add Command Helper

Mock toolkit command for testing.
EOF

        cat > "$HOME/.claude/commands/smart-commit.md" << 'EOF'
---
description: Generate intelligent commit messages
source: claude-toolkit
---

# Smart Commit

Mock toolkit command for testing.
EOF

        # Create user commands
        for i in {1..3}; do
            cat > "$HOME/.claude/commands/test-user-$i.md" << EOF
---
description: Test user command $i
---

# Test User Command $i

Test user command $i for --source all testing.
EOF
        done

        # Get dynamic command lists
        local initial_toolkit_files=($(get_toolkit_command_files "$HOME/.claude/commands"))
        local initial_user_files=($(get_user_command_files "$HOME/.claude/commands"))

        # Verify initial state
        assert_greater_than "${#initial_toolkit_files[@]}" "0" "Should have toolkit commands initially"
        assert_greater_than "${#initial_user_files[@]}" "0" "Should have user commands initially"

        local initial_checksum=$(calculate_directory_checksum "$HOME/.claude/commands")

        # Test uninstall --source all - should ONLY remove toolkit commands, NOT user commands
        local uninstall_output
        uninstall_output=$(assert_command_succeeds "Uninstall --source all should succeed" -- ./scripts/claude-slash.sh uninstall --source all -y 2>&1)

        # Verify toolkit commands were removed
        for toolkit_file in "${initial_toolkit_files[@]}"; do
            assert_file_not_exists "$toolkit_file" "Toolkit command $(basename "$toolkit_file") should be removed after --source all uninstall"
        done

        # Verify user commands were PRESERVED (this is the key fix)
        for user_file in "${initial_user_files[@]}"; do
            assert_file_exists "$user_file" "User command $(basename "$user_file") should be PRESERVED after --source all uninstall"
        done

        # Verify log messages - should not mention removing all commands since user commands are preserved
        assert_contains "Uninstalling files from source(s): all" "$uninstall_output" \
            "Should log uninstalling from all configured sources"

        # Should only remove toolkit commands, preserving user commands
        assert_contains "Successfully uninstalled" "$uninstall_output" \
            "Should show toolkit commands removal"
    )
}

test_uninstall_default_removes_all_configured_sources() {
    (
        create_sandbox

        # Create toolkit commands manually instead of relying on install
        mkdir -p "$HOME/.claude/commands"
        cat > "$HOME/.claude/commands/add-command.md" << 'EOF'
---
description: Create a new Claude Code slash command
source: claude-toolkit
---

# Add Command Helper

Mock toolkit command for testing.
EOF

        cat > "$HOME/.claude/commands/smart-commit.md" << 'EOF'
---
description: Generate intelligent commit messages
source: claude-toolkit
---

# Smart Commit

Mock toolkit command for testing.
EOF

        # Add mock sources to configuration using the proper function
        add_template_source_to_config "team-alpha" "git@github.example.com:team-alpha/slash-commands.git"
        add_template_source_to_config "team-beta" "git@gitlab.internal.com:teams/beta/commands.git"

        # Create commands from multiple sources ad hoc
        cat > "$HOME/.claude/commands/team-alpha-helper.md" << 'EOF'
---
description: Team Alpha helper command
source: team-alpha
---

# Team Alpha Helper

This is a command from the team-alpha source.
EOF

        cat > "$HOME/.claude/commands/team-beta-deploy.md" << 'EOF'
---
description: Team Beta deployment command
source: team-beta
---

# Team Beta Deploy

This is a command from the team-beta source.
EOF

        # Create user commands
        cat > "$HOME/.claude/commands/compat-user-1.md" << 'EOF'
---
description: Compatibility test user command 1
---

# Compatibility User Command 1

User command for testing default uninstall behavior.
EOF

        cat > "$HOME/.claude/commands/compat-user-2.md" << 'EOF'
---
description: Compatibility test user command 2
---

# Compatibility User Command 2

Second user command for testing default uninstall behavior.
EOF

        # Get dynamic command lists
        local initial_toolkit_files=($(get_template_files "$HOME/.claude/commands" | filter_template_files_by_source "claude-toolkit"))
        local initial_team_alpha_files=($(get_template_files "$HOME/.claude/commands" | filter_template_files_by_source "team-alpha"))
        local initial_team_beta_files=($(get_template_files "$HOME/.claude/commands" | filter_template_files_by_source "team-beta"))
        local initial_user_files=($(get_user_command_files "$HOME/.claude/commands"))

        # Verify initial state
        assert_greater_than "${#initial_toolkit_files[@]}" "0" "Should have toolkit commands initially"
        assert_greater_than "${#initial_team_alpha_files[@]}" "0" "Should have team-alpha commands initially"
        assert_greater_than "${#initial_team_beta_files[@]}" "0" "Should have team-beta commands initially"
        assert_greater_than "${#initial_user_files[@]}" "0" "Should have user commands initially"

        # Store initial user command checksums for verification
        local initial_user_checksums=()
        for user_file in "${initial_user_files[@]}"; do
            initial_user_checksums+=($(calculate_file_checksum "$user_file"))
        done

        # Test uninstall without --source (should default to all configured sources and preserve user commands)
        local uninstall_output
        uninstall_output=$(assert_command_succeeds "Uninstall without --source should succeed" -- ./scripts/claude-slash.sh uninstall -y 2>&1)

        # Verify ALL non-user commands were removed (toolkit, team-alpha, team-beta)
        for toolkit_file in "${initial_toolkit_files[@]}"; do
            assert_file_not_exists "$toolkit_file" "Toolkit command $(basename "$toolkit_file") should be removed with default behavior"
        done
        for team_alpha_file in "${initial_team_alpha_files[@]}"; do
            assert_file_not_exists "$team_alpha_file" "Team-alpha command $(basename "$team_alpha_file") should be removed with default behavior"
        done
        for team_beta_file in "${initial_team_beta_files[@]}"; do
            assert_file_not_exists "$team_beta_file" "Team-beta command $(basename "$team_beta_file") should be removed with default behavior"
        done

        # Verify user commands are unchanged by comparing checksums
        for i in "${!initial_user_files[@]}"; do
            local user_file="${initial_user_files[$i]}"
            local initial_checksum="${initial_user_checksums[$i]}"
            local current_checksum=$(calculate_file_checksum "$user_file")
            assert_equals "$initial_checksum" "$current_checksum" "User command $(basename "$user_file") should remain unchanged with default behavior"
        done

        # Verify log messages show default behavior (all sources)
        assert_contains "Uninstalling files from source(s):" "$uninstall_output" \
            "Should log default source behavior"
    )
}

test_user_only_environment_protection() {
    (
        create_sandbox

        mkdir -p "$HOME/.claude/commands"

        # Create several user commands to simulate a user-only environment
        for i in {1..4}; do
            cat > "$HOME/.claude/commands/personal-helper-$i.md" << EOF
---
description: Personal development helper $i
---

# Personal Helper $i

This is user-created personal helper command $i.
EOF
        done

        local user_files=($(get_user_command_files "$HOME/.claude/commands"))
        assert_greater_than "${#user_files[@]}" "0" "Should have user commands in user-only environment"

        # Store user command checksums
        local initial_user_checksums=()
        for user_file in "${user_files[@]}"; do
            local checksum=$(calculate_file_checksum "$user_file")
            initial_user_checksums+=("$checksum")
            assert_not_equals "" "$checksum" "User command $(basename "$user_file") should have valid initial checksum"
        done

        local initial_checksum=$(calculate_directory_checksum "$HOME/.claude/commands")

        local uninstall_output
        uninstall_output=$(assert_command_succeeds "Uninstall should succeed in user-only environment" -- ./scripts/claude-slash.sh uninstall -y 2>&1)

        # Verify user commands are unchanged by comparing checksums
        for i in "${!user_files[@]}"; do
            local user_file="${user_files[$i]}"
            local initial_checksum_val="${initial_user_checksums[$i]}"
            local final_checksum=$(calculate_file_checksum "$user_file")
            assert_equals "$initial_checksum_val" "$final_checksum" "User command $(basename "$user_file") should remain unchanged in user-only uninstall"
        done

        # Directory checksum should be unchanged in user-only environment
        local final_checksum=$(calculate_directory_checksum "$HOME/.claude/commands")
        assert_equals "$initial_checksum" "$final_checksum" "Directory checksum should be unchanged in user-only uninstall"

        assert_directory_exists "$HOME/.claude/commands" "Commands directory should be preserved in user-only environment"

        # The uninstall runs but finds no commands to remove (all are user commands)
        # The script should not output "Successfully uninstalled" when no commands are removed
        # Just verify the user command preservation and no success message

        assert_not_contains "Successfully uninstalled" "$uninstall_output" \
            "Should not show successful uninstall when no commands are removed"
    )
}

test_comma_separated_source_uninstall() {
    (
        create_sandbox

        # Create toolkit commands manually instead of relying on install
        mkdir -p "$HOME/.claude/commands"
        cat > "$HOME/.claude/commands/add-command.md" << 'EOF'
---
description: Create a new Claude Code slash command
source: claude-toolkit
---

# Add Command Helper

Mock toolkit command for testing.
EOF

        cat > "$HOME/.claude/commands/smart-commit.md" << 'EOF'
---
description: Generate intelligent commit messages
source: claude-toolkit
---

# Smart Commit

Mock toolkit command for testing.
EOF

        # Add mock sources to configuration using the proper function
        add_template_source_to_config "team-alpha" "git@bitbucket.internal.org:alpha/commands.git"
        add_template_source_to_config "team-beta" "git@github.corp.example.com:beta-team/slash-commands.git"
        add_template_source_to_config "team-gamma" "git@gitlab.company.net:gamma/cli-commands.git"

        # Create commands from multiple sources ad hoc
        cat > "$HOME/.claude/commands/team-alpha-helper.md" << 'EOF'
---
description: Team Alpha helper command
source: team-alpha
---

# Team Alpha Helper

This is a command from the team-alpha source.
EOF

        cat > "$HOME/.claude/commands/team-beta-deploy.md" << 'EOF'
---
description: Team Beta deployment command
source: team-beta
---

# Team Beta Deploy

This is a command from the team-beta source.
EOF

        cat > "$HOME/.claude/commands/team-gamma-test.md" << 'EOF'
---
description: Team Gamma test command
source: team-gamma
---

# Team Gamma Test

This is a command from the team-gamma source.
EOF

        # Create user commands
        cat > "$HOME/.claude/commands/my-user-helper.md" << 'EOF'
---
description: My personal helper command
---

# My User Helper

This is a user-created command that should be preserved.
EOF

        # Get dynamic command lists
        local initial_toolkit_files=($(get_template_files "$HOME/.claude/commands" | filter_template_files_by_source "claude-toolkit"))
        local initial_team_alpha_files=($(get_template_files "$HOME/.claude/commands" | filter_template_files_by_source "team-alpha"))
        local initial_team_beta_files=($(get_template_files "$HOME/.claude/commands" | filter_template_files_by_source "team-beta"))
        local initial_team_gamma_files=($(get_template_files "$HOME/.claude/commands" | filter_template_files_by_source "team-gamma"))
        local initial_user_files=($(get_user_command_files "$HOME/.claude/commands"))

        # Verify initial state
        assert_greater_than "${#initial_toolkit_files[@]}" "0" "Should have toolkit commands initially"
        assert_greater_than "${#initial_team_alpha_files[@]}" "0" "Should have team-alpha commands initially"
        assert_greater_than "${#initial_team_beta_files[@]}" "0" "Should have team-beta commands initially"
        assert_greater_than "${#initial_team_gamma_files[@]}" "0" "Should have team-gamma commands initially"
        assert_greater_than "${#initial_user_files[@]}" "0" "Should have user commands initially"

        # Test uninstall with comma-separated sources (team-alpha,team-beta)
        local uninstall_output
        uninstall_output=$(assert_command_succeeds "Uninstall with comma-separated sources should succeed" -- ./scripts/claude-slash.sh uninstall --source "team-alpha,team-beta" -y 2>&1)

        # Verify ONLY team-alpha and team-beta commands were removed
        for team_alpha_file in "${initial_team_alpha_files[@]}"; do
            assert_file_not_exists "$team_alpha_file" "Team-alpha command $(basename "$team_alpha_file") should be removed"
        done
        for team_beta_file in "${initial_team_beta_files[@]}"; do
            assert_file_not_exists "$team_beta_file" "Team-beta command $(basename "$team_beta_file") should be removed"
        done

        # Verify toolkit, team-gamma, and user commands were NOT removed
        for toolkit_file in "${initial_toolkit_files[@]}"; do
            assert_file_exists "$toolkit_file" "Toolkit command $(basename "$toolkit_file") should be preserved"
        done
        for team_gamma_file in "${initial_team_gamma_files[@]}"; do
            assert_file_exists "$team_gamma_file" "Team-gamma command $(basename "$team_gamma_file") should be preserved"
        done
        for user_file in "${initial_user_files[@]}"; do
            assert_file_exists "$user_file" "User command $(basename "$user_file") should be preserved"
        done

        # Verify log messages show comma-separated sources
        assert_contains "Uninstalling files from source(s): team-alpha,team-beta" "$uninstall_output" \
            "Should log comma-separated sources"

        assert_contains "Successfully uninstalled" "$uninstall_output" \
            "Should show successful uninstall for specified sources"
    )
}

# Register all test functions
register_tests \
    "test_uninstall_source_user_rejection" \
    "test_uninstall_source_all_commands" \
    "test_uninstall_default_removes_all_configured_sources" \
    "test_user_only_environment_protection" \
    "test_comma_separated_source_uninstall"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-slash.sh multi-source uninstall functionality" "$@"
fi
