#!/bin/bash
# test-claude-slash-uninstall.sh - Refactored tests using dynamic command detection
#
# Purpose: Test scripts/claude-slash.sh uninstall functionality

source "$(dirname "$0")/../utils/test-harness.sh"
source "$(dirname "$0")/../utils/file-utils.sh"
source "$(dirname "$0")/../utils/upstream-repo-utils.sh"

# Source claude-slash.sh to access its functions
source "$(dirname "$0")/../../scripts/claude-slash.sh"

# Enable debug mode for all tests to capture debug messages
export DEBUG=true

# Standard test suite setup function for upstream repository tests
test_suite_setup() {
    setup_upstream_repository
}

# Standard test suite teardown function for upstream repository tests
test_suite_teardown() {
    cleanup_upstream_repository
}

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

test_user_commands_never_removed_by_uninstall_all() {
    (
        create_sandbox

        # Install toolkit commands
        assert_command_succeeds "Initial installation should succeed" -- ./scripts/claude-slash.sh install >/dev/null 2>&1
        assert_directory_exists "$HOME/.claude/commands" "Commands directory should exist after initial install"

        # Create user commands
        cat > "$HOME/.claude/commands/user-helper.md" << 'EOF'
---
description: User helper command that should never be removed
---

# User Helper

This is a user command that should NEVER be removed by uninstall operations.
EOF

        cat > "$HOME/.claude/commands/personal-script.md" << 'EOF'
---
description: Personal script for user workflows
---

# Personal Script

User-created personal automation script.
EOF

        # Get dynamic lists of commands
        local initial_toolkit_files=($(get_toolkit_command_files "$HOME/.claude/commands"))
        local initial_user_files=($(get_user_command_files "$HOME/.claude/commands"))

        # Verify we have both types of commands
        assert_greater_than "${#initial_toolkit_files[@]}" "0" "Should have toolkit commands after install"
        assert_greater_than "${#initial_user_files[@]}" "0" "Should have user commands"

        # Store checksums for verification
        local initial_directory_checksum=$(calculate_directory_checksum "$HOME/.claude/commands")
        local user_checksums=()
        for user_file in "${initial_user_files[@]}"; do
            user_checksums+=($(calculate_file_checksum "$user_file"))
        done

        # Test 1: Uninstall with --source all should NEVER touch user commands
        local uninstall_output
        uninstall_output=$(assert_command_succeeds "Uninstall --source all should succeed" -- ./scripts/claude-slash.sh uninstall --source all -y 2>&1)

        # Verify toolkit commands were removed
        for toolkit_file in "${initial_toolkit_files[@]}"; do
            assert_file_not_exists "$toolkit_file" "Toolkit command $(basename "$toolkit_file") should be removed"
        done

        # Verify user commands were NEVER touched
        local final_user_files=($(get_user_command_files "$HOME/.claude/commands"))
        for i in "${!initial_user_files[@]}"; do
            local user_file="${initial_user_files[$i]}"
            local initial_checksum="${user_checksums[$i]}"

            assert_file_exists "$user_file" "User command $(basename "$user_file") should be preserved"

            local final_checksum=$(calculate_file_checksum "$user_file")
            assert_equals "$initial_checksum" "$final_checksum" "User command $(basename "$user_file") should be unchanged"
        done

        # Verify uninstall messaging correctly reflects user command protection
        assert_not_contains "user" "$uninstall_output" "Uninstall output should not mention user commands when using --source all"
        assert_contains "Successfully uninstalled" "$uninstall_output" "Should show successful toolkit uninstall"
    )
}

test_user_commands_completely_protected_from_removal() {
    (
        create_sandbox

        # Install toolkit commands
        assert_command_succeeds "Initial installation should succeed" -- ./scripts/claude-slash.sh install >/dev/null 2>&1

        # Create user commands
        cat > "$HOME/.claude/commands/protected-user-cmd.md" << 'EOF'
---
description: User command that should never be removable
---

# Protected User Command

This user command should NEVER be removable by any uninstall operation.
EOF

        # Get initial state
        local initial_toolkit_files=($(get_toolkit_command_files "$HOME/.claude/commands"))
        local initial_user_files=($(get_user_command_files "$HOME/.claude/commands"))

        assert_greater_than "${#initial_toolkit_files[@]}" "0" "Should have toolkit commands"
        assert_greater_than "${#initial_user_files[@]}" "0" "Should have user commands"

        # Store user command checksum for verification
        local user_file_checksums=()
        for user_file in "${initial_user_files[@]}"; do
            user_file_checksums+=($(calculate_file_checksum "$user_file"))
        done

        # CRITICAL TEST: --source user should FAIL with error
        local user_uninstall_output
        user_uninstall_output=$(assert_command_fails "Uninstall --source user should FAIL with error" -- ./scripts/claude-slash.sh uninstall --source user -y 2>&1)

        # Verify error messages
        assert_contains "Cannot uninstall user files" "$user_uninstall_output" \
            "Should show error about user command protection"

        # Verify NO commands were removed - both toolkit and user should be unchanged
        for toolkit_file in "${initial_toolkit_files[@]}"; do
            assert_file_exists "$toolkit_file" "Toolkit command $(basename "$toolkit_file") should remain when --source user fails"
        done

        for i in "${!initial_user_files[@]}"; do
            local user_file="${initial_user_files[$i]}"
            local initial_checksum="${user_file_checksums[$i]}"

            assert_file_exists "$user_file" "User command $(basename "$user_file") should remain when --source user fails"

            local final_checksum=$(calculate_file_checksum "$user_file")
            assert_equals "$initial_checksum" "$final_checksum" "User command $(basename "$user_file") should be unchanged when --source user fails"
        done

        # Test comma-separated list with user should also fail
        local comma_uninstall_output
        comma_uninstall_output=$(assert_command_fails "Uninstall with user in comma list should FAIL" -- ./scripts/claude-slash.sh uninstall --source "claude-toolkit,user" -y 2>&1)

        assert_contains "Cannot uninstall user files" "$comma_uninstall_output" \
            "Should reject comma-separated list containing user"

        # Verify all commands still unchanged after comma test
        for i in "${!initial_user_files[@]}"; do
            local user_file="${initial_user_files[$i]}"
            local initial_checksum="${user_file_checksums[$i]}"

            local final_checksum=$(calculate_file_checksum "$user_file")
            assert_equals "$initial_checksum" "$final_checksum" "User command $(basename "$user_file") should remain unchanged after comma test"
        done
    )
}

test_toolkit_only_environment_uninstall() {
    (
        create_sandbox

        # Install toolkit commands only
        assert_command_succeeds "Initial installation should succeed" -- ./scripts/claude-slash.sh install >/dev/null 2>&1
        assert_directory_exists "$HOME/.claude/commands" "Commands directory should exist after initial install"

        local initial_toolkit_files=($(get_toolkit_command_files "$HOME/.claude/commands"))
        local initial_user_files=($(get_user_command_files "$HOME/.claude/commands"))

        assert_greater_than "${#initial_toolkit_files[@]}" "0" "Should have toolkit commands"
        assert_equals "${#initial_user_files[@]}" "0" "Should have no user commands in toolkit-only environment"

        local initial_checksum=$(calculate_directory_checksum "$HOME/.claude/commands")

        local uninstall_output
        uninstall_output=$(assert_command_succeeds "Uninstall should succeed" -- ./scripts/claude-slash.sh uninstall -y 2>&1)

        # Verify all toolkit commands were removed
        for toolkit_file in "${initial_toolkit_files[@]}"; do
            assert_file_not_exists "$toolkit_file" "Toolkit command $(basename "$toolkit_file") should be removed in toolkit-only uninstall"
        done

        # Verify no commands remain in the directory
        local final_command_files=($(get_template_files "$HOME/.claude/commands"))
        assert_equals "${#final_command_files[@]}" "0" "Should have no command files after toolkit-only uninstall"

        assert_contains "Successfully uninstalled" "$uninstall_output" "Should show complete removal summary"
    )
}

test_mixed_environment_selective_uninstall() {
    (
        create_sandbox

        # Install toolkit commands and create user commands
        assert_command_succeeds "Initial installation should succeed" -- ./scripts/claude-slash.sh install >/dev/null 2>&1

        # Create multiple user commands
        for i in {1..3}; do
            cat > "$HOME/.claude/commands/user-cmd-$i.md" << EOF
---
description: User command $i for testing
---

# User Command $i

This is user command $i that should be preserved during toolkit uninstall.
EOF
        done

        local initial_toolkit_files=($(get_toolkit_command_files "$HOME/.claude/commands"))
        local initial_user_files=($(get_user_command_files "$HOME/.claude/commands"))

        assert_greater_than "${#initial_toolkit_files[@]}" "0" "Should have toolkit commands"
        assert_greater_than "${#initial_user_files[@]}" "0" "Should have user commands"

        # Store user command checksums
        local initial_user_checksums=()
        for user_file in "${initial_user_files[@]}"; do
            initial_user_checksums+=($(calculate_file_checksum "$user_file"))
        done

        # Uninstall toolkit commands only (default behavior)
        local uninstall_output
        uninstall_output=$(assert_command_succeeds "Mixed environment uninstall should succeed" -- ./scripts/claude-slash.sh uninstall -y 2>&1)

        # Verify selective removal
        for toolkit_file in "${initial_toolkit_files[@]}"; do
            assert_file_not_exists "$toolkit_file" "Toolkit command $(basename "$toolkit_file") should be removed"
        done

        # Verify user command preservation
        local final_user_files=($(get_user_command_files "$HOME/.claude/commands"))
        assert_equals "${#initial_user_files[@]}" "${#final_user_files[@]}" "Should preserve all user commands"

        for i in "${!initial_user_files[@]}"; do
            local user_file="${initial_user_files[$i]}"
            local initial_checksum="${initial_user_checksums[$i]}"

            assert_file_exists "$user_file" "User command $(basename "$user_file") should be preserved"

            local final_checksum=$(calculate_file_checksum "$user_file")
            assert_equals "$initial_checksum" "$final_checksum" "User command $(basename "$user_file") should be unchanged"
        done

        assert_contains "User files will be preserved" "$uninstall_output" "Should inform about user command preservation"
    )
}

# Register all test functions
register_tests \
    "test_user_commands_never_removed_by_uninstall_all" \
    "test_user_commands_completely_protected_from_removal" \
    "test_toolkit_only_environment_uninstall" \
    "test_mixed_environment_selective_uninstall"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-slash.sh uninstall functionality" "$@"
fi
