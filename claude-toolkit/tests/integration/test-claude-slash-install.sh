#!/bin/bash
# test-claude-slash-install.sh - Tests claude-slash.sh install functionality
# 
# Purpose: Test scripts/claude-slash.sh installation functionality according to streamlined design
# Dependencies: None

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

test_install() {
    (
        create_sandbox

        assert_command_succeeds "Installation should succeed" -- ./scripts/claude-slash.sh install >/dev/null 2>&1
        
        assert_directory_exists "$HOME/.claude/commands" "Commands directory should be created"

        local checksum_before
        checksum_before=$(calculate_directory_checksum "$HOME/.claude/commands" "*.md")

        local install_output
        install_output=$(assert_command_succeeds "Second installation should succeed" -- ./scripts/claude-slash.sh install 2>&1)

        assert_contains "All files already installed" "$install_output" "Should signal that all files are already installed"

        local checksum_after
        checksum_after=$(calculate_directory_checksum "$HOME/.claude/commands" "*.md")

        assert_equals "$checksum_before" "$checksum_after" "Install should be idempotent"
    )
}

test_install_adds_new_files() {
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
            install_output=$(assert_command_succeeds "Second installation should succeed" -- ./scripts/claude-slash.sh install 2>&1)

            assert_not_contains "All files already installed" "$install_output" "Should not signal that all files are already installed"

            local checksum_after
            checksum_after=$(calculate_directory_checksum "$HOME/.claude/commands" "*.md")

            assert_not_equals "$checksum_before" "$checksum_after" "Install should update commands"

            assert_file_exists "$HOME/.claude/commands/my-command.md" "New command should be available after second install"
        )
    )
}

test_install_fails_on_changed_files() {
    (
        create_sandbox

        assert_command_succeeds "First installation should succeed" -- ./scripts/claude-slash.sh install >/dev/null 2>&1

        local checksum_before
        checksum_before=$(calculate_directory_checksum "$HOME/.claude/commands" "*.md")

        echo "User change 1" >>"$HOME/.claude/commands/smart-commit.md"

        local checksum_after_change
        checksum_after_change=$(calculate_directory_checksum "$HOME/.claude/commands" "*.md")

        assert_not_equals "$checksum_before" "$checksum_after_change" "User change should be detected after modifying the command file"

        local install_output
        install_output=$(assert_command_fails "Second installation should fail" -- ./scripts/claude-slash.sh install 2>&1)

        local checksum_after
        checksum_after=$(calculate_directory_checksum "$HOME/.claude/commands" "*.md")

        assert_equals "$checksum_after_change" "$checksum_after" "Failed install should not change installed commands"
    )
}

test_install_succeeds_on_upstream_changes() {
    (
        setup_upstream_repository
        trap 'cleanup_upstream_repository' ERR
        trap 'cleanup_upstream_repository' EXIT
        (
            create_sandbox

            # First installation
            assert_command_succeeds "First installation should succeed" -- ./scripts/claude-slash.sh install >/dev/null 2>&1

            local checksum_before
            checksum_before=$(calculate_file_checksum "$HOME/.claude/commands/smart-commit.md")

            # Simulate upstream change by modifying the file in the upstream repository
            echo "# Updated content from upstream" >> "$DEFAULT_REMOTE_REPOSITORY/slash-commands/smart-commit.md"
            git -C "$DEFAULT_REMOTE_REPOSITORY" add .
            git -C "$DEFAULT_REMOTE_REPOSITORY" commit -m "Updated smart-commit command" >/dev/null 2>&1

            # Second installation should succeed and update the file
            local install_output
            install_output=$(assert_command_succeeds "Second installation should succeed with upstream changes" -- ./scripts/claude-slash.sh install 2>&1)

            assert_not_contains "All files already installed" "$install_output" "Should not signal that all files are already installed"
            assert_not_contains "contains user changes" "$install_output" "Should not report user changes when user hasn't modified file"

            local checksum_after
            checksum_after=$(calculate_file_checksum "$HOME/.claude/commands/smart-commit.md")

            assert_not_equals "$checksum_before" "$checksum_after" "File should be updated with upstream changes"

            # Verify the upstream content is present
            assert_file_contains "$HOME/.claude/commands/smart-commit.md" "Updated content from upstream" "File should contain upstream changes"
        )
    )
}


test_install_succeeds_on_orphaned_tracked_files() {
    (
        setup_upstream_repository
        trap 'cleanup_upstream_repository' ERR
        trap 'cleanup_upstream_repository' EXIT
        (
            create_sandbox

            # Create a command in the upstream repository and install it
            cat > "$DEFAULT_REMOTE_REPOSITORY/slash-commands/temp-command.md" << 'EOF'
---
description: Temporary command for orphan test
source: claude-toolkit
---
# Temp Command
This command will be removed from upstream to test orphan handling.
EOF
            git -C "$DEFAULT_REMOTE_REPOSITORY" add .
            git -C "$DEFAULT_REMOTE_REPOSITORY" commit -m "Added temp command" >/dev/null 2>&1

            # First installation - this creates snapshot
            assert_command_succeeds "First installation should succeed" -- ./scripts/claude-slash.sh install >/dev/null 2>&1
            assert_file_exists "$HOME/.claude/commands/temp-command.md" "Temp command should be installed"

            # Now remove the command from upstream repository
            rm "$DEFAULT_REMOTE_REPOSITORY/slash-commands/temp-command.md"
            git -C "$DEFAULT_REMOTE_REPOSITORY" add .
            git -C "$DEFAULT_REMOTE_REPOSITORY" commit -m "Removed temp command" >/dev/null 2>&1

            # Second installation should succeed and remove the orphaned file
            local install_output
            install_output=$(assert_command_succeeds "Second installation should succeed and remove orphaned file" -- ./scripts/claude-slash.sh install 2>&1)

            assert_contains "removed orphaned file: temp-command.md" "$install_output" "Should report orphaned file removal"
            assert_file_not_exists "$HOME/.claude/commands/temp-command.md" "Orphaned file should be removed"
        )
    )
}

test_install_fails_on_orphaned_user_created_files() {
    (
        create_sandbox

        # Create a user command that looks like it's from toolkit but was user-created
        mkdir -p "$HOME/.claude/commands"
        cat > "$HOME/.claude/commands/my-fake-toolkit-command.md" << 'EOF'
---
description: User command masquerading as toolkit
source: claude-toolkit
---
# User Created Command
This was created by user but claims to be from toolkit.
EOF

        # Get checksum before installation attempt
        local checksum_before
        checksum_before=$(calculate_file_checksum "$HOME/.claude/commands/my-fake-toolkit-command.md")

        # Try to install - should fail because orphaned file is not tracked in snapshot
        local install_output
        install_output=$(assert_command_fails "Installation should fail with untracked orphaned file" -- ./scripts/claude-slash.sh install 2>&1)

        assert_contains "orphaned installed file: my-fake-toolkit-command.md (not tracked - possibly user-created)" "$install_output" "Should detect untracked orphaned file"
        
        # Verify file is unchanged using checksum
        local checksum_after
        checksum_after=$(calculate_file_checksum "$HOME/.claude/commands/my-fake-toolkit-command.md")
        assert_equals "$checksum_before" "$checksum_after" "User-created file should remain unchanged after failed install"
    )
}

test_install_fails_on_orphaned_modified_files() {
    (
        setup_upstream_repository
        trap 'cleanup_upstream_repository' ERR
        trap 'cleanup_upstream_repository' EXIT
        (
            create_sandbox

            # Create a command in the upstream repository and install it
            cat > "$DEFAULT_REMOTE_REPOSITORY/slash-commands/modifiable-command.md" << 'EOF'
---
description: Command that will be modified by user
source: claude-toolkit
---
# Modifiable Command
This command will be modified by user.
EOF
            git -C "$DEFAULT_REMOTE_REPOSITORY" add .
            git -C "$DEFAULT_REMOTE_REPOSITORY" commit -m "Added modifiable command" >/dev/null 2>&1

            # First installation - this creates snapshot
            assert_command_succeeds "First installation should succeed" -- ./scripts/claude-slash.sh install >/dev/null 2>&1
            assert_file_exists "$HOME/.claude/commands/modifiable-command.md" "Command should be installed"

            # User modifies the file
            echo "User added content" >> "$HOME/.claude/commands/modifiable-command.md"

            # Get checksum after user modification
            local checksum_after_user_change
            checksum_after_user_change=$(calculate_file_checksum "$HOME/.claude/commands/modifiable-command.md")

            # Remove the command from upstream repository
            rm "$DEFAULT_REMOTE_REPOSITORY/slash-commands/modifiable-command.md"
            git -C "$DEFAULT_REMOTE_REPOSITORY" add .
            git -C "$DEFAULT_REMOTE_REPOSITORY" commit -m "Removed modifiable command" >/dev/null 2>&1

            # Second installation should fail because file has user changes
            local install_output
            install_output=$(assert_command_fails "Installation should fail with user-modified orphaned file" -- ./scripts/claude-slash.sh install 2>&1)

            assert_contains "orphaned installed file: modifiable-command.md (contains user changes - use reinstall to force)" "$install_output" "Should detect user-modified orphaned file"
            
            # Verify file is unchanged using checksum
            local checksum_after_failed_install
            checksum_after_failed_install=$(calculate_file_checksum "$HOME/.claude/commands/modifiable-command.md")
            assert_equals "$checksum_after_user_change" "$checksum_after_failed_install" "User-modified file should remain unchanged after failed install"
        )
    )
}

test_install_preserves_user_commands() {
    (
        create_sandbox

        mkdir -p "$HOME/.claude/commands"
        
        cat > "$HOME/.claude/commands/my-user-command.md" << 'EOF'
---
description: A user-created command
---

# My User Command

This is a user-created command that should be preserved during installation.
EOF

        assert_file_exists "$HOME/.claude/commands/my-user-command.md" "User command should exist before installation"

        local checksum_before
        checksum_before=$(calculate_file_checksum "$HOME/.claude/commands/my-user-command.md")

        assert_command_succeeds "Installation should succeed with user commands present" -- ./scripts/claude-slash.sh install >/dev/null 2>&1

        local checksum_after
        checksum_after=$(calculate_file_checksum "$HOME/.claude/commands/my-user-command.md")

        assert_equals "$checksum_before" "$checksum_after" "User command files should remain unchanged after installation"
    )
}

test_install_handles_command_conflicts() {
    (
        create_sandbox

        mkdir -p "$HOME/.claude/commands"
        
        cat > "$HOME/.claude/commands/smart-commit.md" << 'EOF'
---
description: User's custom smart commit command
---

# User's Smart Commit Command

This is a user-created smart-commit command that conflicts with the toolkit version.
EOF

        assert_file_exists "$HOME/.claude/commands/smart-commit.md" "User smart-commit command should exist before installation"

        local checksum_before
        checksum_before=$(calculate_file_checksum "$HOME/.claude/commands/smart-commit.md")

        assert_command_succeeds "Installation should succeed" -- ./scripts/claude-slash.sh install >/dev/null 2>&1
        
        local checksum_after
        checksum_after=$(calculate_file_checksum "$HOME/.claude/commands/smart-commit.md")
        
        assert_equals "$checksum_before" "$checksum_after" "User command files should remain unchanged after installation"

        assert_file_exists "$HOME/.claude/commands/smart-commit-claude-toolkit.md" "Installed command should be renamed"
    )
}

test_install_error_handling_permission_issues() {
    (
        create_sandbox

        mkdir -p "$HOME/.claude"
        chmod 444 "$HOME/.claude"

        assert_command_fails "Installation should fail with permission issues" -- ./scripts/claude-slash.sh install >/dev/null 2>&1

        chmod 755 "$HOME/.claude" 2>/dev/null || true
        rm -rf "$HOME/.claude" 2>/dev/null || true

        # Create the commands directory structure but make the commands directory read-only
        mkdir -p "$HOME/.claude/commands"
        chmod 444 "$HOME/.claude/commands"
        
        assert_command_fails "Installation should fail with read-only commands directory" -- ./scripts/claude-slash.sh install >/dev/null 2>&1
        
        chmod 755 "$HOME/.claude/commands" 2>/dev/null || true
    )
}

# Register all test functions
register_tests \
    "test_install" \
    "test_install_adds_new_files" \
    "test_install_fails_on_changed_files" \
    "test_install_succeeds_on_upstream_changes" \
    "test_install_preserves_user_commands" \
    "test_install_handles_command_conflicts" \
    "test_install_succeeds_on_orphaned_tracked_files" \
    "test_install_fails_on_orphaned_user_created_files" \
    "test_install_fails_on_orphaned_modified_files" \
    "test_install_error_handling_permission_issues"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-slash.sh install functionality" "$@"
fi
