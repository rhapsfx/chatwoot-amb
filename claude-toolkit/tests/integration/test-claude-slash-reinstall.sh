#!/bin/bash
# test-claude-slash-reinstall.sh - Tests claude-slash.sh reinstall functionality
# 
# Purpose: Test scripts/claude-slash.sh --reinstall functionality
# Dependencies: test-claude-slash-install.sh (for setup)

source "$(dirname "$0")/../utils/test-harness.sh"
source "$(dirname "$0")/../utils/file-utils.sh"
source "$(dirname "$0")/../utils/upstream-repo-utils.sh"

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

test_reinstall() {
    (
        create_sandbox

        assert_command_succeeds "Initial installation should succeed" -- ./scripts/claude-slash.sh install >/dev/null 2>&1

        local checksum_before
        checksum_before=$(calculate_directory_checksum "$HOME/.claude/commands" "*.md")

        assert_command_succeeds "Reinstall should succeed" -- ./scripts/claude-slash.sh reinstall >/dev/null 2>&1

        local checksum_after
        checksum_after=$(calculate_directory_checksum "$HOME/.claude/commands" "*.md")

        assert_equals "$checksum_before" "$checksum_after" "Reinstall should be idempotent when there were no intermediate changes"
    )
}

test_reinstall_adds_new_files() {
    (
        setup_upstream_repository
        trap 'cleanup_upstream_repository' ERR
        trap 'cleanup_upstream_repository' EXIT
        (
            create_sandbox

            assert_command_succeeds "Installation should succeed" -- ./scripts/claude-slash.sh install >/dev/null 2>&1

            local checksum_before
            checksum_before=$(calculate_directory_checksum "$HOME/.claude/commands" "*.md")

            cat > "$DEFAULT_REMOTE_REPOSITORY/slash-commands/my-command.md" << 'EOF'
---
description: My command
source: claude-toolkit
---
# My Command
New command in upstream repository.
EOF
            git -C "$DEFAULT_REMOTE_REPOSITORY" add .
            git -C "$DEFAULT_REMOTE_REPOSITORY" commit -m "Added new command" >/dev/null 2>&1

            assert_file_not_exists "$HOME/.claude/commands/my-command.md" "New command should not be available before second install"

            local install_output
            install_output=$(assert_command_succeeds "Reinstall should succeed" -- ./scripts/claude-slash.sh reinstall 2>&1)

            local checksum_after
            checksum_after=$(calculate_directory_checksum "$HOME/.claude/commands" "*.md")

            assert_not_equals "$checksum_before" "$checksum_after" "Install should update commands"

            assert_file_exists "$HOME/.claude/commands/my-command.md" "New command should be available after second install"
        )
    )
}

test_reinstall_overwrites_changed_files() {
    (
        create_sandbox

        assert_command_succeeds "Initial installation should succeed" -- ./scripts/claude-slash.sh install >/dev/null 2>&1

        local checksum_before
        checksum_before=$(calculate_directory_checksum "$HOME/.claude/commands" "*.md")

        echo "User change 1" >>"$HOME/.claude/commands/smart-commit.md"

        local checksum_after_change
        checksum_after_change=$(calculate_directory_checksum "$HOME/.claude/commands" "*.md")

        assert_not_equals "$checksum_before" "$checksum_after_change" "User change should be detected after modifying the command file"

        assert_command_succeeds "Reinstall should succeed" -- ./scripts/claude-slash.sh reinstall >/dev/null 2>&1

        local checksum_after_reinstall
        checksum_after_reinstall=$(calculate_directory_checksum "$HOME/.claude/commands" "*.md")

        assert_equals "$checksum_before" "$checksum_after_reinstall" "Reinstall should overwrite changes in installed files"
    )
}

test_reinstall_removes_orphaned_files() {
    (
        setup_upstream_repository
        trap 'cleanup_upstream_repository' ERR
        trap 'cleanup_upstream_repository' EXIT
        (
            create_sandbox

            assert_command_succeeds "Installation should succeed" -- ./scripts/claude-slash.sh install >/dev/null 2>&1

            # Capture checksum before adding orphaned file
            local checksum_before_orphan_added
            checksum_before_orphan_added=$(calculate_directory_checksum "$HOME/.claude/commands" "*.md")

            # Create an orphaned file - a command that exists locally but not in upstream
            cat > "$HOME/.claude/commands/orphaned-command.md" << 'EOF'
---
description: An orphaned command that will be removed
source: claude-toolkit
---
# Orphaned Command
This command exists locally but not in the upstream repository and should be removed during reinstall.
EOF

            # Verify the orphaned file exists
            assert_file_exists "$HOME/.claude/commands/orphaned-command.md" "Orphaned file should exist before reinstall"

            # Reinstall should remove the orphaned file
            local reinstall_output
            reinstall_output=$(assert_command_succeeds "Reinstall should succeed" -- ./scripts/claude-slash.sh reinstall 2>&1)

            # Verify the orphaned file was removed
            assert_file_not_exists "$HOME/.claude/commands/orphaned-command.md" "Orphaned file should be removed after reinstall"

            # Verify output mentions the removal
            assert_contains "removed orphaned file: orphaned-command.md" "$reinstall_output" "Should report orphaned file removal"

            local checksum_after_reinstall
            checksum_after_reinstall=$(calculate_directory_checksum "$HOME/.claude/commands" "*.md")

            # The checksum should match the original state (before orphaned file was added)
            assert_equals "$checksum_before_orphan_added" "$checksum_after_reinstall" "Reinstall should restore original state by removing orphaned file"

            # Verify that legitimate commands still exist
            assert_file_exists "$HOME/.claude/commands/smart-commit.md" "Legitimate commands should still exist"
        )
    )
}

test_reinstall_preserves_user_commands() {
    (
        create_sandbox

        # First install toolkit commands
        assert_command_succeeds "Initial installation should succeed" -- ./scripts/claude-slash.sh install >/dev/null 2>&1
        
        # Create user commands that should be preserved during reinstall
        cat > "$HOME/.claude/commands/my-user-command.md" << 'EOF'
---
description: A user-created command
---

# My User Command

This is a user-created command that should be preserved during reinstall.
EOF
        local command_file_checksum_before
        command_file_checksum_before=$(calculate_file_checksum "$HOME/.claude/commands/my-user-command.md")

        local checksum_before
        checksum_before=$(calculate_directory_checksum "$HOME/.claude/commands" "*.md")

        echo "User change 1" >>"$HOME/.claude/commands/smart-commit.md"

        local checksum_after_change
        checksum_after_change=$(calculate_directory_checksum "$HOME/.claude/commands" "*.md")

        assert_not_equals "$checksum_before" "$checksum_after_change" "User change should be detected after modifying the command file"

        assert_command_succeeds "Reinstall should succeed" -- ./scripts/claude-slash.sh reinstall >/dev/null 2>&1

        local command_file_checksum_after
        command_file_checksum_after=$(calculate_file_checksum "$HOME/.claude/commands/my-user-command.md")

        local checksum_after_reinstall
        checksum_after_reinstall=$(calculate_directory_checksum "$HOME/.claude/commands" "*.md")

        assert_equals "$checksum_before" "$checksum_after_reinstall" "Reinstall should overwrite changes in installed files"

        assert_equals "$command_file_checksum_before" "$command_file_checksum_after" "Reinstall should not modify user commands"
    )
}

test_reinstall_handles_command_conflicts() {
    (
        create_sandbox

        assert_command_succeeds "Initial installation should succeed" -- ./scripts/claude-slash.sh install >/dev/null 2>&1
        
        # Create user version of smart-commit.md (conflicts with toolkit)
        cat > "$HOME/.claude/commands/smart-commit.md" << 'EOF'
---
description: My custom smart commit (user version)
---

# My Smart Commit

This is my custom user-created smart commit command that conflicts with the toolkit version.
EOF
        local checksum_before
        checksum_before=$(calculate_file_checksum "$HOME/.claude/commands/smart-commit.md")

        assert_command_succeeds "Reinstall should succeed" -- ./scripts/claude-slash.sh reinstall >/dev/null 2>&1

        local checksum_after
        checksum_after=$(calculate_file_checksum "$HOME/.claude/commands/smart-commit.md")

        assert_equals "$checksum_before" "$checksum_after" "User command files should remain unchanged after installation"

        assert_file_exists "$HOME/.claude/commands/smart-commit-claude-toolkit.md" "Installed command should be renamed"
    )
}

test_reinstall_error_handling_permission_issues() {
    (
        create_sandbox
        assert_command_succeeds "Initial installation should succeed" -- ./scripts/claude-slash.sh install >/dev/null 2>&1

        chmod 444 "$HOME/.claude"

        assert_command_fails "Reinstall should fail with permission issues" -- ./scripts/claude-slash.sh reinstall >/dev/null 2>&1

        chmod 755 "$HOME/.claude" 2>/dev/null || true
        rm -rf "$HOME/.claude" 2>/dev/null || true

        # Create the commands directory structure but make the commands directory read-only
        mkdir -p "$HOME/.claude/commands"
        chmod 444 "$HOME/.claude/commands"

        assert_command_fails "Reinstall should fail with read-only commands directory" -- ./scripts/claude-slash.sh reinstall >/dev/null 2>&1

        chmod 755 "$HOME/.claude/commands" 2>/dev/null || true
    )
}

# Register all test functions
register_tests \
    "test_reinstall" \
    "test_reinstall_adds_new_files" \
    "test_reinstall_overwrites_changed_files" \
    "test_reinstall_removes_orphaned_files" \
    "test_reinstall_preserves_user_commands" \
    "test_reinstall_handles_command_conflicts" \
    "test_reinstall_error_handling_permission_issues" \

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-slash.sh reinstall functionality" "$@"
fi
