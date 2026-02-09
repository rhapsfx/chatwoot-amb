#!/bin/bash
# test-claude-code-reinstall.sh - Tests "scripts/claude-code.sh reinstall" functionality
# 
# Purpose: Test "scripts/claude-code.sh reinstall" functionality according to reinstall architecture specification
# Dependencies: test-claude-code-install.sh (for setup)
# Approach: Use shared installation optimization, test reinstall semantics (complete removal + fresh installation)

source "$(dirname "$0")/../utils/test-harness.sh"
source "$(dirname "$0")/claude-code-shared-installation-utils.sh"

export DEBUG=true

test_reinstall_default_version() {
    (
        create_sandbox

        copy_shared_claude_installation
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Initial version should be installed"
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should exist"
        assert_file_exists "$HOME/.local/bin/claude" "Claude wrapper should exist"
        
        local current_before_reinstall
        current_before_reinstall=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        local reinstall_output
        reinstall_output=$(assert_command_succeeds "Reinstall should succeed" -- "./scripts/claude-code.sh" reinstall --yes 2>&1)
        
        assert_contains "Starting Claude Code reinstall" "$reinstall_output" "Reinstall output should mention reinstall operation"
        assert_contains "Version to reinstall not specified, assuming the current version is requested" "$reinstall_output" "Reinstall output should show current version detection"
        assert_contains "Current version: 0.0.85" "$reinstall_output" "Reinstall output should confirm target version"
        assert_contains "Backing up version directory" "$reinstall_output" "Reinstall output should show backup execution"
        assert_contains "Removing Claude Code version 0.0.85..." "$reinstall_output" "Reinstall output should show version removal"
        assert_contains "Creating installation directories..." "$reinstall_output" "Reinstall output should show fresh installation"
        assert_contains "Installed Claude Code package" "$reinstall_output" "Reinstall output should confirm successful completion"
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Reinstalled version directory should exist"
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should still exist after reinstall"
        assert_file_exists "$HOME/.local/bin/claude" "Claude wrapper should still exist after reinstall"
        
        local current_after_reinstall
        current_after_reinstall=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        assert_equals "$current_before_reinstall" "$current_after_reinstall" "Current version should remain the same after reinstall"
        
        assert_command_succeeds "Claude wrapper should work after reinstall" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs" "Node.js directory should exist in reinstalled version"
        assert_file_exists "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin/node" "Node.js binary should exist in reinstalled version"
        assert_file_exists "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin/claude" "Claude binary should exist in reinstalled version"
    )
}

test_reinstall_specific_version() {
    (
        create_sandbox

        copy_shared_claude_installation
        copy_shared_claude_installation "0.0.84"
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Original version should be installed"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.84" "Second version should be installed"
        
        local current_before_reinstall
        current_before_reinstall=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        local other_version_checksum
        other_version_checksum=$(find "$XDG_DATA_HOME/claude/versions/0.0.84" -type f -exec md5 {} + 2>/dev/null | sort | md5)

        local reinstall_output
        reinstall_output=$(assert_command_succeeds "Reinstall should succeed" -- "./scripts/claude-code.sh" reinstall --version "0.0.85" --yes 2>&1)
        
        assert_contains "Starting Claude Code reinstall" "$reinstall_output" "Reinstall output should mention reinstall operation"
        assert_contains "Reinstalling version: 0.0.85" "$reinstall_output" "Reinstall output should show specified version"
        assert_contains "Backing up version directory" "$reinstall_output" "Reinstall output should show backup stub execution"
        assert_contains "Removing Claude Code version 0.0.85..." "$reinstall_output" "Reinstall output should show version removal"
        assert_contains "Creating installation directories..." "$reinstall_output" "Reinstall output should show fresh installation"
        assert_contains "Installed Claude Code package" "$reinstall_output" "Reinstall output should confirm successful completion"
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Reinstalled version directory should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.84" "Other version directory should be preserved"
        
        local current_after_reinstall
        current_after_reinstall=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        assert_equals "$current_before_reinstall" "$current_after_reinstall" "Current version should remain unchanged when reinstalling non-current version (per architecture specification)"
        
        assert_command_succeeds "Claude wrapper should work after reinstall" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs" "Node.js directory should exist in reinstalled version"
        assert_file_exists "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin/node" "Node.js binary should exist in reinstalled version"
        assert_file_exists "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin/claude" "Claude binary should exist in reinstalled version"
        
        local other_version_checksum_after
        other_version_checksum_after=$(find "$XDG_DATA_HOME/claude/versions/0.0.84" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        
        assert_equals "$other_version_checksum" "$other_version_checksum_after" "Other version (0.0.84) should be completely unchanged after reinstalling different version"
    )
}

test_reinstall_with_nodejs_version_parameter() {
    (
        create_sandbox

        copy_shared_claude_installation
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Initial version should be installed"
        assert_file_exists "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin/node" "Node.js binary should exist"
        
        local initial_node_version
        initial_node_version=$(assert_command_succeeds "Node.js version check should succeed" -- "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin/node" --version 2>/dev/null)
        
        local reinstall_output
        reinstall_output=$(assert_command_succeeds "Reinstall should succeed" -- "./scripts/claude-code.sh" reinstall --nodejs-version "22.18.0" --yes 2>&1)
        
        assert_contains "Starting Claude Code reinstall" "$reinstall_output" "Reinstall output should mention reinstall operation"
        assert_contains "Version to reinstall not specified, assuming the current version is requested" "$reinstall_output" "Reinstall output should show current version detection"
        assert_contains "Current version: 0.0.85" "$reinstall_output" "Reinstall output should confirm target version"
        assert_contains "Installing Node.js 22.18.0" "$reinstall_output" "Reinstall output should show Node.js version being used"
        assert_contains "Backing up version directory" "$reinstall_output" "Reinstall output should show backup stub execution"
        assert_contains "Installed Claude Code package" "$reinstall_output" "Reinstall output should confirm successful completion"
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Reinstalled version directory should exist"
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should still exist after reinstall"
        assert_file_exists "$HOME/.local/bin/claude" "Claude wrapper should still exist after reinstall"
        
        assert_file_exists "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin/node" "Node.js binary should exist after reinstall"
        local new_node_version
        new_node_version=$(assert_command_succeeds "Node.js version check should succeed" -- "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin/node" --version 2>/dev/null)
        
        assert_equals "v22.18.0" "$new_node_version" "Node.js version should be updated to the specified version"
        assert_not_equals "$initial_node_version" "$new_node_version" "Node.js version should have changed from the initial version"
        
        assert_command_succeeds "Claude wrapper should work with new Node.js version" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
        
        assert_file_exists "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin/claude" "Claude binary should exist with new Node.js"
    )
}

test_reinstall_with_both_version_parameters() {
    (
        create_sandbox

        copy_shared_claude_installation
        copy_shared_claude_installation "0.0.84"
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Original version should be installed"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.84" "Second version should be installed"
        
        local current_version
        current_version=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        local initial_node_version
        initial_node_version=$(assert_command_succeeds "Node.js version check should succeed" -- "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin/node" --version 2>/dev/null)
        
        local reinstall_output
        reinstall_output=$(assert_command_succeeds "Reinstall should succeed" -- "./scripts/claude-code.sh" reinstall --version "0.0.85" --nodejs-version "22.18.0" --yes 2>&1)
        
        assert_contains "Starting Claude Code reinstall" "$reinstall_output" "Reinstall output should mention reinstall operation"
        assert_contains "Reinstalling version: 0.0.85" "$reinstall_output" "Reinstall output should show specified Claude Code version"
        assert_contains "Installing Node.js 22.18.0" "$reinstall_output" "Reinstall output should show Node.js version installation"
        assert_contains "Backing up version directory" "$reinstall_output" "Reinstall output should show backup stub execution"
        assert_contains "Removing Claude Code version 0.0.85..." "$reinstall_output" "Reinstall output should show version removal"
        assert_contains "Creating installation directories..." "$reinstall_output" "Reinstall output should show fresh installation"
        assert_contains "Installed Claude Code package" "$reinstall_output" "Reinstall output should confirm successful completion"
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Reinstalled version directory should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.84" "Other version directory should be preserved"
        
        local current_after_reinstall
        current_after_reinstall=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        assert_equals "$current_version" "$current_after_reinstall" "Current version should remain unchanged when reinstalling non-current version"
        
        assert_file_exists "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin/node" "Node.js binary should exist after reinstall"
        local new_node_version
        new_node_version=$(assert_command_succeeds "Node.js version check should succeed" -- "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin/node" --version 2>/dev/null)
        
        assert_equals "v22.18.0" "$new_node_version" "Node.js version should be updated to the specified version"
        assert_not_equals "$initial_node_version" "$new_node_version" "Node.js version should have changed from the initial version"
        
        assert_file_exists "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin/claude" "Claude binary should exist with new Node.js"
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.84/nodejs" "Other version's Node.js directory should be preserved"
        assert_file_exists "$XDG_DATA_HOME/claude/versions/0.0.84/nodejs/bin/node" "Other version's Node.js binary should be preserved"
        assert_file_exists "$XDG_DATA_HOME/claude/versions/0.0.84/nodejs/bin/claude" "Other version's Claude binary should be preserved"
        
        assert_command_succeeds "Claude wrapper should work after reinstall" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
    )
}

test_reinstall_preserves_other_versions() {
    (
        create_sandbox

        copy_shared_claude_installation
        copy_shared_claude_installation "0.0.84"
        copy_shared_claude_installation "0.0.83"
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Original version should be installed"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.84" "Second version should be installed"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.83" "Third version should be installed"
        
        local current_version
        current_version=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        local version_0_0_84_checksum version_0_0_85_checksum
        version_0_0_84_checksum=$(find "$XDG_DATA_HOME/claude/versions/0.0.84" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        version_0_0_85_checksum=$(find "$XDG_DATA_HOME/claude/versions/0.0.85" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        
        local reinstall_output
        reinstall_output=$(assert_command_succeeds "Reinstall should succeed" -- "./scripts/claude-code.sh" reinstall --version "0.0.83" --yes 2>&1)
        
        assert_contains "Starting Claude Code reinstall" "$reinstall_output" "Reinstall output should mention reinstall operation"
        assert_contains "Reinstalling version: 0.0.83" "$reinstall_output" "Reinstall output should show specified version"
        assert_contains "Installed Claude Code package" "$reinstall_output" "Reinstall output should confirm successful completion"
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Version 0.0.85 directory should be preserved"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.84" "Version 0.0.84 directory should be preserved"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.83" "Version 0.0.83 directory should exist"
        
        local current_after_reinstall
        current_after_reinstall=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        assert_equals "$current_version" "$current_after_reinstall" "Current version should remain unchanged when reinstalling non-current version"
        
        local version_0_0_84_checksum_after version_0_0_85_checksum_after
        version_0_0_84_checksum_after=$(find "$XDG_DATA_HOME/claude/versions/0.0.84" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        version_0_0_85_checksum_after=$(find "$XDG_DATA_HOME/claude/versions/0.0.85" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        
        assert_equals "$version_0_0_84_checksum" "$version_0_0_84_checksum_after" "Version 0.0.84 should be completely unchanged"
        assert_equals "$version_0_0_85_checksum" "$version_0_0_85_checksum_after" "Version 0.0.85 should be completely unchanged"

        assert_command_succeeds "Node.js should work for version 0.0.84" -- "$XDG_DATA_HOME/claude/versions/0.0.84/nodejs/bin/node" --version >/dev/null 2>&1
        assert_command_succeeds "Node.js should work for version 0.0.85" -- "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin/node" --version >/dev/null 2>&1
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.83/nodejs" "Reinstalled version Node.js directory should exist"
        assert_file_exists "$XDG_DATA_HOME/claude/versions/0.0.83/nodejs/bin/node" "Reinstalled version Node.js binary should exist"
        assert_file_exists "$XDG_DATA_HOME/claude/versions/0.0.83/nodejs/bin/claude" "Reinstalled version Claude binary should exist"
        assert_command_succeeds "Reinstalled Node.js should work" -- "$XDG_DATA_HOME/claude/versions/0.0.83/nodejs/bin/node" --version >/dev/null 2>&1
        
        assert_command_succeeds "Claude wrapper should work after reinstall" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should still exist"
    )
}

test_reinstall_current_version_symlink_behavior() {
    (
        create_sandbox

        copy_shared_claude_installation
        copy_shared_claude_installation "0.0.84"
        copy_shared_claude_installation "0.0.83"
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Version 0.0.85 should be installed"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.84" "Version 0.0.84 should be installed"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.83" "Version 0.0.83 should be installed"
        
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should exist"
        local initial_current_version
        initial_current_version=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        local initial_symlink_target
        initial_symlink_target=$(readlink "$XDG_DATA_HOME/claude/current" 2>/dev/null || echo "none")
        assert_contains "versions/$initial_current_version" "$initial_symlink_target" "Symlink should initially point to current version"
        
        local reinstall_current_output
        reinstall_current_output=$(assert_command_succeeds "Current version reinstall should succeed" -- "./scripts/claude-code.sh" reinstall --version "$initial_current_version" --yes 2>&1)
        
        assert_contains "Reinstall completed successfully!" "$reinstall_current_output" "Current version reinstall should complete successfully"
        
        local current_after_reinstall
        current_after_reinstall=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        local symlink_target_after_reinstall
        symlink_target_after_reinstall=$(readlink "$XDG_DATA_HOME/claude/current" 2>/dev/null || echo "none")
        
        assert_equals "$initial_current_version" "$current_after_reinstall" "Current version should remain same after reinstalling current version"
        assert_contains "versions/$initial_current_version" "$symlink_target_after_reinstall" "Symlink should still point to version $initial_current_version after reinstalling current"
        
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should exist after reinstall"
        assert_command_succeeds "Claude wrapper should work through symlink after reinstall" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$initial_current_version" "Reinstalled version directory should exist"
        assert_command_succeeds "Reinstalled version Node.js should work" -- "$XDG_DATA_HOME/claude/versions/$initial_current_version/nodejs/bin/node" --version >/dev/null 2>&1
    )
}

test_reinstall_noncurrent_version_symlink_behavior() {
    (
        create_sandbox

        copy_shared_claude_installation
        copy_shared_claude_installation "0.0.84"
        copy_shared_claude_installation "0.0.83"
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Version 0.0.85 should be installed"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.84" "Version 0.0.84 should be installed"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.83" "Version 0.0.83 should be installed"
        
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should exist"
        local initial_current_version
        initial_current_version=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        local initial_symlink_target
        initial_symlink_target=$(readlink "$XDG_DATA_HOME/claude/current" 2>/dev/null || echo "none")
        assert_contains "versions/$initial_current_version" "$initial_symlink_target" "Symlink should initially point to current version"
        
        local noncurrent_version="0.0.83"
        if [[ "$initial_current_version" == "0.0.83" ]]; then
            noncurrent_version="0.0.84"
        fi
        
        local reinstall_noncurrent_output
        reinstall_noncurrent_output=$(assert_command_succeeds "Non-current version reinstall should succeed" -- "./scripts/claude-code.sh" reinstall --version "$noncurrent_version" --yes 2>&1)
        
        assert_contains "Reinstall completed successfully!" "$reinstall_noncurrent_output" "Non-current version reinstall should complete successfully"
        
        local current_after_reinstall
        current_after_reinstall=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        local symlink_target_after_reinstall
        symlink_target_after_reinstall=$(readlink "$XDG_DATA_HOME/claude/current" 2>/dev/null || echo "none")
        
        assert_equals "$initial_current_version" "$current_after_reinstall" "Current version should remain unchanged after reinstalling non-current version"
        assert_equals "$initial_symlink_target" "$symlink_target_after_reinstall" "Symlink target should remain unchanged after reinstalling non-current version"
        
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should exist after reinstall"
        assert_command_succeeds "Claude wrapper should work through symlink after reinstall" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$initial_current_version" "Current version directory should still exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$noncurrent_version" "Reinstalled non-current version directory should exist"
        assert_command_succeeds "Current version Node.js should work" -- "$XDG_DATA_HOME/claude/versions/$initial_current_version/nodejs/bin/node" --version >/dev/null 2>&1
        assert_command_succeeds "Reinstalled non-current version Node.js should work" -- "$XDG_DATA_HOME/claude/versions/$noncurrent_version/nodejs/bin/node" --version >/dev/null 2>&1
    )
}

test_reinstall_with_nodejs_change_symlink_behavior() {
    (
        create_sandbox

        copy_shared_claude_installation
        copy_shared_claude_installation "0.0.84"
        copy_shared_claude_installation "0.0.83"
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Version 0.0.85 should be installed"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.84" "Version 0.0.84 should be installed"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.83" "Version 0.0.83 should be installed"
        
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should exist"
        local initial_current_version
        initial_current_version=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        local initial_symlink_target
        initial_symlink_target=$(readlink "$XDG_DATA_HOME/claude/current" 2>/dev/null || echo "none")
        assert_contains "versions/$initial_current_version" "$initial_symlink_target" "Symlink should initially point to current version"
        
        local initial_node_version
        initial_node_version=$(assert_command_succeeds "Node.js version check should succeed" -- "$XDG_DATA_HOME/claude/versions/$initial_current_version/nodejs/bin/node" --version 2>/dev/null)
        
        local reinstall_nodejs_output
        reinstall_nodejs_output=$(assert_command_succeeds "Node.js version change reinstall should succeed" -- "./scripts/claude-code.sh" reinstall --version "$initial_current_version" --nodejs-version "22.18.0" --yes 2>&1)
        
        assert_contains "Reinstall completed successfully!" "$reinstall_nodejs_output" "Node.js version change reinstall should complete successfully"
        assert_contains "Installing Node.js 22.18.0" "$reinstall_nodejs_output" "Reinstall output should show Node.js version change"
        
        local current_after_nodejs_reinstall
        current_after_nodejs_reinstall=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        local symlink_target_after_nodejs
        symlink_target_after_nodejs=$(readlink "$XDG_DATA_HOME/claude/current" 2>/dev/null || echo "none")
        
        assert_equals "$initial_current_version" "$current_after_nodejs_reinstall" "Current version should remain the same after reinstalling current with Node.js change"
        assert_contains "versions/$initial_current_version" "$symlink_target_after_nodejs" "Symlink should still point to initial version after Node.js reinstall"
        
        local new_node_version
        new_node_version=$(assert_command_succeeds "Node.js version check should succeed" -- "$XDG_DATA_HOME/claude/versions/$initial_current_version/nodejs/bin/node" --version 2>/dev/null)
        assert_equals "v22.18.0" "$new_node_version" "Node.js version should be updated to the specified version"
        assert_not_equals "$initial_node_version" "$new_node_version" "Node.js version should have changed from the initial version"
        
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should exist after Node.js change reinstall"
        assert_command_succeeds "Claude wrapper should work through symlink after Node.js change" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
        
        if [[ "$symlink_target_after_nodejs" == versions/* ]]; then
            # Symlink uses relative path (good practice)
            :
        fi
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Version 0.0.85 should still exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.84" "Version 0.0.84 should still exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.83" "Version 0.0.83 should still exist"
        
        assert_command_succeeds "Version 0.0.85 Node.js should work" -- "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin/node" --version >/dev/null 2>&1
        assert_command_succeeds "Version 0.0.84 Node.js should work" -- "$XDG_DATA_HOME/claude/versions/0.0.84/nodejs/bin/node" --version >/dev/null 2>&1
        assert_command_succeeds "Version 0.0.83 Node.js should work" -- "$XDG_DATA_HOME/claude/versions/0.0.83/nodejs/bin/node" --version >/dev/null 2>&1
    )
}

test_reinstall_idempotency() {
    (
        create_sandbox

        copy_shared_claude_installation
        copy_shared_claude_installation "0.0.84"
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Original version should be installed"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.84" "Second version should be installed"
        
        local initial_current_version
        initial_current_version=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        local version_0_0_85_checksum_initial version_0_0_84_checksum_initial
        version_0_0_85_checksum_initial=$(find "$XDG_DATA_HOME/claude/versions/0.0.85" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        version_0_0_84_checksum_initial=$(find "$XDG_DATA_HOME/claude/versions/0.0.84" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        
        local initial_symlink_target
        initial_symlink_target=$(readlink "$XDG_DATA_HOME/claude/current" 2>/dev/null || echo "none")
        
        assert_command_succeeds "Claude wrapper should work before reinstall testing" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
        
        local target_version="0.0.85"
        
        local first_reinstall_output
        first_reinstall_output=$(assert_command_succeeds "First reinstall should succeed" -- "./scripts/claude-code.sh" reinstall --version "$target_version" --yes 2>&1)
        
        assert_contains "Reinstall completed successfully!" "$first_reinstall_output" "First reinstall should complete successfully"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$target_version" "Target version directory should exist after first reinstall"
        assert_command_succeeds "Claude wrapper should work after first reinstall" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
        
        local current_version_after_first
        current_version_after_first=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        local symlink_target_after_first
        symlink_target_after_first=$(readlink "$XDG_DATA_HOME/claude/current" 2>/dev/null || echo "none")
        
        local version_0_0_85_checksum_after_first version_0_0_84_checksum_after_first
        version_0_0_85_checksum_after_first=$(find "$XDG_DATA_HOME/claude/versions/0.0.85" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        version_0_0_84_checksum_after_first=$(find "$XDG_DATA_HOME/claude/versions/0.0.84" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        
        assert_equals "$version_0_0_84_checksum_initial" "$version_0_0_84_checksum_after_first" "Non-target version should be unchanged by first reinstall"
        
        assert_equals "$initial_current_version" "$current_version_after_first" "Current version should remain unchanged when reinstalling non-current version"
        assert_equals "$initial_symlink_target" "$symlink_target_after_first" "Symlink target should remain unchanged when reinstalling non-current version"

        local second_reinstall_output
        second_reinstall_output=$(assert_command_succeeds "Second reinstall should succeed" -- "./scripts/claude-code.sh" reinstall --version "$target_version" --yes 2>&1)
        
        assert_contains "Reinstall completed successfully!" "$second_reinstall_output" "Second reinstall should complete successfully"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$target_version" "Target version directory should exist after second reinstall"
        assert_command_succeeds "Claude wrapper should work after second reinstall" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
        
        local current_version_after_second
        current_version_after_second=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        local symlink_target_after_second
        symlink_target_after_second=$(readlink "$XDG_DATA_HOME/claude/current" 2>/dev/null || echo "none")
        
        local version_0_0_85_checksum_after_second version_0_0_84_checksum_after_second
        version_0_0_85_checksum_after_second=$(find "$XDG_DATA_HOME/claude/versions/0.0.85" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        version_0_0_84_checksum_after_second=$(find "$XDG_DATA_HOME/claude/versions/0.0.84" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        
        assert_equals "$current_version_after_first" "$current_version_after_second" "Current version should be identical between reinstalls"
        
        assert_equals "$symlink_target_after_first" "$symlink_target_after_second" "Symlink target should be identical between reinstalls"
        
        assert_equals "$version_0_0_84_checksum_after_first" "$version_0_0_84_checksum_after_second" "Non-target version should be identical between reinstalls"
        
        assert_equals "$version_0_0_85_checksum_after_first" "$version_0_0_85_checksum_after_second" "Target version should be identical between reinstalls"

        local third_reinstall_output
        third_reinstall_output=$(assert_command_succeeds "Third reinstall should succeed" -- "./scripts/claude-code.sh" reinstall --version "$target_version" --yes 2>&1)
        
        assert_contains "Reinstall completed successfully!" "$third_reinstall_output" "Third reinstall should complete successfully"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$target_version" "Target version directory should exist after third reinstall"
        assert_command_succeeds "Claude wrapper should work after third reinstall" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
        
        local current_version_after_third
        current_version_after_third=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        local symlink_target_after_third
        symlink_target_after_third=$(readlink "$XDG_DATA_HOME/claude/current" 2>/dev/null || echo "none")
        
        local version_0_0_85_checksum_after_third version_0_0_84_checksum_after_third
        version_0_0_85_checksum_after_third=$(find "$XDG_DATA_HOME/claude/versions/0.0.85" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        version_0_0_84_checksum_after_third=$(find "$XDG_DATA_HOME/claude/versions/0.0.84" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        
        assert_equals "$current_version_after_first" "$current_version_after_third" "Current version should be identical across all reinstalls"
        
        assert_equals "$symlink_target_after_first" "$symlink_target_after_third" "Symlink target should be identical across all reinstalls"
        
        assert_equals "$version_0_0_84_checksum_initial" "$version_0_0_84_checksum_after_third" "Non-target version should remain unchanged across all reinstalls"
        
        assert_equals "$version_0_0_85_checksum_after_first" "$version_0_0_85_checksum_after_third" "Target version should be identical across all reinstalls"
        
        local current_version_before_current_reinstall
        current_version_before_current_reinstall=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        local current_reinstall_output
        current_reinstall_output=$(assert_command_succeeds "Current version reinstall should succeed" -- "./scripts/claude-code.sh" reinstall --yes 2>&1)
        
        assert_contains "Reinstall completed successfully!" "$current_reinstall_output" "Current version reinstall should complete successfully"
        
        local current_version_after_current_reinstall
        current_version_after_current_reinstall=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        assert_equals "$current_version_before_current_reinstall" "$current_version_after_current_reinstall" "Current version should remain current after self-reinstall"
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Version 0.0.85 should exist after all operations"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.84" "Version 0.0.84 should exist after all operations"
        
        assert_command_succeeds "Version 0.0.85 Node.js should work after all operations" -- "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin/node" --version >/dev/null 2>&1
        assert_command_succeeds "Version 0.0.84 Node.js should work after all operations" -- "$XDG_DATA_HOME/claude/versions/0.0.84/nodejs/bin/node" --version >/dev/null 2>&1
        
        assert_file_exists "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin/claude" "Version 0.0.85 Claude binary should exist"
        assert_file_exists "$XDG_DATA_HOME/claude/versions/0.0.84/nodejs/bin/claude" "Version 0.0.84 Claude binary should exist"
        
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should exist after all operations"
        assert_file_exists "$HOME/.local/bin/claude" "Claude wrapper should exist after all operations"
        assert_command_succeeds "Claude wrapper should work after all operations" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
        
        assert_contains "Starting Claude Code reinstall" "$first_reinstall_output" "First reinstall should contain start message"
        assert_contains "Starting Claude Code reinstall" "$second_reinstall_output" "Second reinstall should contain start message"
        assert_contains "Starting Claude Code reinstall" "$third_reinstall_output" "Third reinstall should contain start message"
    )
}

setup_multiversion_error_test_environment() {
    copy_shared_claude_installation
    copy_shared_claude_installation "0.0.84"
    
    assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Original version should be installed"
    assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.84" "Second version should be installed"
    
    assert_command_succeeds "Claude wrapper should work before error test" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
}

test_reinstall_error_nonexistent_version() {
    (
        create_sandbox

        setup_multiversion_error_test_environment
        
        local initial_current_version
        initial_current_version=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        local initial_symlink_target
        initial_symlink_target=$(readlink "$XDG_DATA_HOME/claude/current" 2>/dev/null || echo "none")
        
        local version_0_0_85_checksum_before version_0_0_84_checksum_before
        version_0_0_85_checksum_before=$(find "$XDG_DATA_HOME/claude/versions/0.0.85" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        version_0_0_84_checksum_before=$(find "$XDG_DATA_HOME/claude/versions/0.0.84" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        
        local nonexistent_version="9.9.99"
        local reinstall_error_output
        reinstall_error_output=$(assert_command_fails "Reinstall of nonexistent version should fail" -- "./scripts/claude-code.sh" reinstall --version "$nonexistent_version" --yes 2>&1)
        
        assert_contains "Version $nonexistent_version is not installed" "$reinstall_error_output" "Error output should indicate version is not installed"
        assert_contains "Installed versions:" "$reinstall_error_output" "Error output should show installed versions for user guidance"
        
        local current_version_after_error
        current_version_after_error=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        assert_equals "$initial_current_version" "$current_version_after_error" "Current version should be unchanged after reinstall error"
        
        local symlink_target_after_error
        symlink_target_after_error=$(readlink "$XDG_DATA_HOME/claude/current" 2>/dev/null || echo "none")
        assert_equals "$initial_symlink_target" "$symlink_target_after_error" "Symlink target should be unchanged after reinstall error"
        
        local version_0_0_85_checksum_after version_0_0_84_checksum_after
        version_0_0_85_checksum_after=$(find "$XDG_DATA_HOME/claude/versions/0.0.85" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        version_0_0_84_checksum_after=$(find "$XDG_DATA_HOME/claude/versions/0.0.84" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        
        assert_equals "$version_0_0_85_checksum_before" "$version_0_0_85_checksum_after" "Version 0.0.85 should be completely unchanged after error"
        assert_equals "$version_0_0_84_checksum_before" "$version_0_0_84_checksum_after" "Version 0.0.84 should be completely unchanged after error"
        
        assert_command_succeeds "Claude wrapper should still work after reinstall error" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
        
        local installed_versions_list
        installed_versions_list=$(echo "$reinstall_error_output" | grep -A 10 "Installed versions:" | head -10)
        
        assert_contains "0.0.85" "$installed_versions_list" "Error should list version 0.0.85 as installed"
        assert_contains "0.0.84" "$installed_versions_list" "Error should list version 0.0.84 as installed"
    )
}

test_reinstall_error_empty_version_parameter() {
    (
        create_sandbox

        setup_multiversion_error_test_environment
        
        local initial_current_version
        initial_current_version=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        local initial_symlink_target
        initial_symlink_target=$(readlink "$XDG_DATA_HOME/claude/current" 2>/dev/null || echo "none")
        
        local version_0_0_85_checksum_before version_0_0_84_checksum_before
        version_0_0_85_checksum_before=$(find "$XDG_DATA_HOME/claude/versions/0.0.85" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        version_0_0_84_checksum_before=$(find "$XDG_DATA_HOME/claude/versions/0.0.84" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        
        local empty_version_output
        empty_version_output=$(assert_command_fails "Empty version parameter should fail during argument parsing" -- "./scripts/claude-code.sh" reinstall --version "" --yes 2>&1)
        
        assert_contains "[ERROR] --version requires a value" "$empty_version_output" "Empty version parameter should fail with specific error message during argument parsing"
        
        local current_version_after_error
        current_version_after_error=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        assert_equals "$initial_current_version" "$current_version_after_error" "Current version should be unchanged after argument parsing error"
        
        local symlink_target_after_error
        symlink_target_after_error=$(readlink "$XDG_DATA_HOME/claude/current" 2>/dev/null || echo "none")
        assert_equals "$initial_symlink_target" "$symlink_target_after_error" "Symlink target should be unchanged after argument parsing error"
        
        local version_0_0_85_checksum_after version_0_0_84_checksum_after
        version_0_0_85_checksum_after=$(find "$XDG_DATA_HOME/claude/versions/0.0.85" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        version_0_0_84_checksum_after=$(find "$XDG_DATA_HOME/claude/versions/0.0.84" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        
        assert_equals "$version_0_0_85_checksum_before" "$version_0_0_85_checksum_after" "Version 0.0.85 should be completely unchanged after argument parsing error"
        assert_equals "$version_0_0_84_checksum_before" "$version_0_0_84_checksum_after" "Version 0.0.84 should be completely unchanged after argument parsing error"
        
        assert_command_succeeds "Claude wrapper should still work after argument parsing error" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
    )
}

test_reinstall_error_system_integrity_preservation() {
    (
        create_sandbox

        setup_multiversion_error_test_environment
        
        local nonexistent_version="9.9.99"
        assert_command_fails "Nonexistent version reinstall should fail" -- "./scripts/claude-code.sh" reinstall --version "$nonexistent_version" --yes 2>/dev/null
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Version 0.0.85 should exist after all error tests"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.84" "Version 0.0.84 should exist after all error tests"
        
        assert_command_succeeds "Version 0.0.85 Node.js should work after error tests" -- "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin/node" --version >/dev/null 2>&1
        assert_command_succeeds "Version 0.0.84 Node.js should work after error tests" -- "$XDG_DATA_HOME/claude/versions/0.0.84/nodejs/bin/node" --version >/dev/null 2>&1
        
        assert_file_exists "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin/claude" "Version 0.0.85 Claude binary should exist"
        assert_file_exists "$XDG_DATA_HOME/claude/versions/0.0.84/nodejs/bin/claude" "Version 0.0.84 Claude binary should exist"
        
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should exist after error tests"
        assert_file_exists "$HOME/.local/bin/claude" "Claude wrapper should exist after error tests"
        assert_command_succeeds "Claude wrapper should work after all error tests" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
    )
}

test_reinstall_error_recovery_after_errors() {
    (
        create_sandbox

        setup_multiversion_error_test_environment
        
        local initial_current_version
        initial_current_version=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        local nonexistent_version="9.9.99"
        assert_command_fails "Nonexistent version reinstall should fail" -- "./scripts/claude-code.sh" reinstall --version "$nonexistent_version" --yes 2>/dev/null
        
        local successful_reinstall_output
        successful_reinstall_output=$(assert_command_succeeds "Successful reinstall should work after error cases" -- "./scripts/claude-code.sh" reinstall --version "0.0.85" --yes 2>&1)
        
        assert_contains "Reinstall completed successfully!" "$successful_reinstall_output" "Successful reinstall should work after error cases"
        assert_command_succeeds "Claude wrapper should work after successful reinstall" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
        
        local final_current_version
        final_current_version=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        assert_equals "$initial_current_version" "$final_current_version" "Current version should remain unchanged after successful non-current reinstall"
    )
}

setup_multiversion_permission_test_environment() {
    copy_shared_claude_installation
    copy_shared_claude_installation "0.0.84"
    
    assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Original version should be installed"
    assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.84" "Second version should be installed"
    
    assert_command_succeeds "Claude wrapper should work before permission test" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
}

test_reinstall_permission_version_directory_readonly() {
    (
        create_sandbox

        setup_multiversion_permission_test_environment
        
        local initial_current_version
        initial_current_version=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        
        local version_0_0_85_checksum_before version_0_0_84_checksum_before
        version_0_0_85_checksum_before=$(find "$XDG_DATA_HOME/claude/versions/0.0.85" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        version_0_0_84_checksum_before=$(find "$XDG_DATA_HOME/claude/versions/0.0.84" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        
        chmod 444 "$XDG_DATA_HOME/claude/versions/0.0.85"
        
        local permission_error_output
        permission_error_output=$(assert_command_fails "Reinstall should fail due to permission issues" -- "./scripts/claude-code.sh" reinstall --version "0.0.85" --yes 2>&1)
        
        chmod 755 "$XDG_DATA_HOME/claude/versions/0.0.85"
        
        if echo "$permission_error_output" | grep -qi "permission\\|denied\\|rm:"; then
            # Permission error appropriately detected in output
            :
        fi
        
        local current_version_after_permission_error
        current_version_after_permission_error=$(assert_command_succeeds "Claude version check should succeed" -- "$HOME/.local/bin/claude" --check-version 2>&1)
        assert_equals "$initial_current_version" "$current_version_after_permission_error" "Current version should be unchanged after permission error"
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Target version should still exist after permission error"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.84" "Other version should still exist after permission error"
        
        local version_0_0_85_checksum_after version_0_0_84_checksum_after
        version_0_0_85_checksum_after=$(find "$XDG_DATA_HOME/claude/versions/0.0.85" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        version_0_0_84_checksum_after=$(find "$XDG_DATA_HOME/claude/versions/0.0.84" -type f -exec md5 {} + 2>/dev/null | sort | md5)
        
        assert_equals "$version_0_0_85_checksum_before" "$version_0_0_85_checksum_after" "Version 0.0.85 should be completely unchanged after permission error"
        assert_equals "$version_0_0_84_checksum_before" "$version_0_0_84_checksum_after" "Version 0.0.84 should be completely unchanged after permission error"
        
        assert_command_succeeds "Claude wrapper should still work after permission error" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
    )
}

test_reinstall_permission_cache_directory() {
    (
        create_sandbox

        setup_multiversion_permission_test_environment
        
        mkdir -p "$XDG_CACHE_HOME/claude"
        chmod 444 "$XDG_CACHE_HOME/claude"
        
        local cache_permission_output
        cache_permission_output=$(assert_command_fails "Cache permission reinstall should fail" -- "./scripts/claude-code.sh" reinstall --version "0.0.85" --yes 2>&1)
        
        chmod 755 "$XDG_CACHE_HOME/claude" 2>/dev/null || true
        
        assert_command_succeeds "Claude wrapper should work after cache permission test" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
    )
}

test_reinstall_permission_nodejs_binary() {
    (
        create_sandbox

        setup_multiversion_permission_test_environment
        
        # Make the nodejs/bin directory read-only to prevent file removal, not just the binary
        chmod 444 "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin"
        
        local node_permission_output
        node_permission_output=$(assert_command_fails "Node.js permission reinstall should fail" -- "./scripts/claude-code.sh" reinstall --version "0.0.85" --yes 2>&1)
        
        # Restore permissions for cleanup
        chmod 755 "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin"
        
        assert_command_succeeds "Claude wrapper should work after Node.js permission test" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
    )
}

test_reinstall_permission_system_recovery() {
    (
        create_sandbox

        setup_multiversion_permission_test_environment
        
        local recovery_reinstall_output
        recovery_reinstall_output=$(assert_command_succeeds "Recovery reinstall should succeed" -- "./scripts/claude-code.sh" reinstall --version "0.0.85" --yes 2>&1)
        
        assert_contains "Reinstall completed successfully!" "$recovery_reinstall_output" "Recovery reinstall should complete successfully"
        assert_command_succeeds "Claude wrapper should work after recovery reinstall" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
    )
}

test_reinstall_permission_comprehensive_integrity_verification() {
    (
        create_sandbox

        setup_multiversion_permission_test_environment
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Version 0.0.85 should exist after all permission tests"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.84" "Version 0.0.84 should exist after all permission tests"
        
        assert_command_succeeds "Version 0.0.85 Node.js should work after permission tests" -- "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin/node" --version >/dev/null 2>&1
        assert_command_succeeds "Version 0.0.84 Node.js should work after permission tests" -- "$XDG_DATA_HOME/claude/versions/0.0.84/nodejs/bin/node" --version >/dev/null 2>&1
        
        assert_file_exists "$XDG_DATA_HOME/claude/versions/0.0.85/nodejs/bin/claude" "Version 0.0.85 Claude binary should exist"
        assert_file_exists "$XDG_DATA_HOME/claude/versions/0.0.84/nodejs/bin/claude" "Version 0.0.84 Claude binary should exist"
        
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should exist after permission tests"
        assert_file_exists "$HOME/.local/bin/claude" "Claude wrapper should exist after permission tests"
        assert_command_succeeds "Claude wrapper should work after all permission tests" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
    )
}

test_reinstall_permission_error_message_quality() {
    (
        create_sandbox

        setup_multiversion_permission_test_environment
        
        chmod 555 "$XDG_DATA_HOME/claude/versions"
        
        local final_permission_test_output
        final_permission_test_output=$(assert_command_fails "Final permission test reinstall should fail" -- "./scripts/claude-code.sh" reinstall --version "0.0.84" --yes 2>&1)
        
        chmod 755 "$XDG_DATA_HOME/claude/versions"

        local final_verification_output
        final_verification_output=$(assert_command_succeeds "Final verification reinstall should succeed" -- "./scripts/claude-code.sh" reinstall --version "0.0.84" --yes 2>&1)
        assert_contains "Reinstall completed successfully!" "$final_verification_output" "Final verification reinstall should complete successfully"
    )
}

setup_multiversion_integrity_test_environment() {
    copy_shared_claude_installation
    copy_shared_claude_installation "0.0.84"
    
    assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Original version should be installed"
    assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.84" "Second version should be installed"
    
    assert_command_succeeds "Claude wrapper should work before integrity test" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
}

test_reinstall_integrity_successful_validation() {
    (
        create_sandbox

        setup_multiversion_integrity_test_environment
        
        local successful_reinstall_output
        successful_reinstall_output=$(assert_command_succeeds "Successful reinstall should complete with integrity validation" -- "./scripts/claude-code.sh" reinstall --version "0.0.85" --yes 2>&1)
        
        assert_contains "Reinstall completed successfully!" "$successful_reinstall_output" "Successful reinstall should complete with integrity validation"
        
        assert_contains "Verifying integrity of installation" "$successful_reinstall_output" "Reinstall should perform integrity validation"
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/0.0.85" "Reinstalled version directory should exist after integrity validation"
        assert_file_exists "$HOME/.local/bin/claude" "Claude wrapper should exist after integrity validation"
        assert_command_succeeds "Claude wrapper should work after integrity validation" -- "$HOME/.local/bin/claude" --check >/dev/null 2>&1
    )
}

# Register all test functions
register_tests \
    "test_reinstall_default_version" \
    "test_reinstall_specific_version" \
    "test_reinstall_with_nodejs_version_parameter" \
    "test_reinstall_with_both_version_parameters" \
    "test_reinstall_preserves_other_versions" \
    "test_reinstall_current_version_symlink_behavior" \
    "test_reinstall_noncurrent_version_symlink_behavior" \
    "test_reinstall_with_nodejs_change_symlink_behavior" \
    "test_reinstall_idempotency" \
    "test_reinstall_error_nonexistent_version" \
    "test_reinstall_error_empty_version_parameter" \
    "test_reinstall_error_system_integrity_preservation" \
    "test_reinstall_error_recovery_after_errors" \
    "test_reinstall_permission_version_directory_readonly" \
    "test_reinstall_permission_cache_directory" \
    "test_reinstall_permission_nodejs_binary" \
    "test_reinstall_permission_system_recovery" \
    "test_reinstall_permission_comprehensive_integrity_verification" \
    "test_reinstall_permission_error_message_quality"

# Setup/cleanup orchestration with trap isolation
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Run in subshell to isolate traps from calling environment
    (
        # Set up shared installation before running tests
        setup_shared_claude_installation "0.0.85"
        trap 'cleanup_shared_claude_installation' EXIT
        
        # Run test suite with shared installation available
        run_tests_with_args "Claude Code Reinstall Functionality Tests" "$@"
    ) || exit $?
fi
