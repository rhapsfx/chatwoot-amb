#!/bin/bash
# test-claude-toolkit-update.sh - Tests "scripts/claude-toolkit.sh update" functionality
# 
# Purpose: Test "scripts/claude-toolkit.sh update" functionality with real update workflow
# Dependencies: None (no shared installation utils - tests genuine update commands only)
# Approach: Use real update command invocations with upstream repository simulation in isolated sandboxes

source "$(dirname "$0")/../utils/test-harness.sh"
source "$(dirname "$0")/../utils/upstream-repo-utils.sh"
source "$(dirname "$0")/../utils/random-utils.sh"

export DEBUG=true

# Standard test suite setup function for upstream repository tests
test_suite_setup() {
    setup_upstream_repository
}

# Standard test suite teardown function for upstream repository tests
test_suite_teardown() {
    cleanup_upstream_repository
}

test_update_comprehensive_functionality() {
    (
        create_sandbox

        setup_fake_all_shells

        # First install Claude Toolkit to have something to update
        local install_output
        install_output=$(assert_command_succeeds "Installation should succeed before update" -- \
            "./scripts/claude-toolkit.sh" install 2>&1)
        
        # Verify installation was successful
        local install_dir="$XDG_DATA_HOME/claude-toolkit"
        local bin_dir="$XDG_BIN_DIR"
        
        assert_directory_exists "$install_dir" "Install directory should exist before update"
        assert_directory_exists "$install_dir/.git" "Install directory should be a git repository before update"
        assert_symlink_exists "$bin_dir/claude-toolkit" "claude-toolkit symlink should exist before update"
        assert_symlink_exists "$bin_dir/claude-template-sources" "claude-template-sources symlink should exist before update"
        
        # Create a simulated change in the upstream repository
        local current_dir=$(pwd)
        cd "$upstream_repo_sandbox_dir/upstream-repo"
        echo "# Updated content" >> README.md
        git add README.md
        git commit -m "Test update commit" >/dev/null 2>&1
        cd "$current_dir"
        
        # Test update command
        local update_output
        update_output=$(assert_command_succeeds "Update should succeed" -- \
            "./scripts/claude-toolkit.sh" update 2>&1)
        
        # Verify update completed successfully
        assert_contains "Updating Claude Toolkit" "$update_output" "Should show updating message"
        assert_contains "Claude Toolkit updated" "$update_output" "Should show success message"
        assert_contains "Claude Toolkit validated, everything looks OK" "$update_output" "Should show validation success"
        
        # Verify repository structure is still intact after update
        assert_directory_exists "$install_dir" "Install directory should exist after update"
        assert_directory_exists "$install_dir/.git" "Install directory should be a git repository after update"
        assert_symlink_exists "$bin_dir/claude-toolkit" "claude-toolkit symlink should exist after update"
        assert_symlink_exists "$bin_dir/claude-code" "claude-code symlink should exist after update"
        assert_symlink_exists "$bin_dir/claude-slash" "claude-slash symlink should exist after update"
        assert_symlink_exists "$bin_dir/claude-template-sources" "claude-template-sources symlink should exist after update"
        
        # Verify the update was actually pulled (check for the new content)
        assert_file_contains "$install_dir/README.md" "Updated content" "Updated content should be present after update"
        
        # Verify shell configurations are still intact
        local script_marker_start="# >>> claude-toolkit.sh start >>>"
        
        if [[ -f "$sandbox_dir/.bash_profile" ]]; then
            local bash_profile_content=$(cat "$sandbox_dir/.bash_profile")
            assert_contains "$script_marker_start" "$bash_profile_content" "Bash config should still contain script markers after update"
        fi
        
        if [[ -f "$sandbox_dir/.zshrc" ]]; then
            local zshrc_content=$(cat "$sandbox_dir/.zshrc")
            assert_contains "$script_marker_start" "$zshrc_content" "Zsh config should still contain script markers after update"
        fi
    )
}

test_update_when_not_installed() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # Try to update when nothing is installed - this triggers reinstall
        local update_output
        update_output=$(assert_command_succeeds "Update should succeed by reinstalling when not installed" -- \
            "./scripts/claude-toolkit.sh" update 2>&1)
        
        # Should show detection of missing/invalid repository and trigger reinstall
        assert_contains "Repository at ~/.local/share/claude-toolkit is invalid or corrupted" "$update_output" "Should detect no installation"
        assert_contains "Reinstalling Claude Toolkit" "$update_output" "Should trigger reinstall"
        assert_contains "Claude Toolkit installed" "$update_output" "Should complete reinstall successfully"
        
        # Verify installation completed successfully
        local install_dir="$XDG_DATA_HOME/claude-toolkit"
        assert_directory_exists "$install_dir" "Install directory should exist after update-reinstall"
        assert_directory_exists "$install_dir/.git" "Install directory should be a git repository after update-reinstall"
    )
}

test_update_with_corrupted_repository() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # First install Claude Toolkit
        local install_output
        install_output=$(assert_command_succeeds "Installation should succeed before corrupting" -- \
            "./scripts/claude-toolkit.sh" install 2>&1)
        
        local install_dir="$XDG_DATA_HOME/claude-toolkit"
        assert_directory_exists "$install_dir" "Install directory should exist before corruption"
        
        # Corrupt the git repository by removing .git directory
        rm -rf "$install_dir/.git"
        
        # Update should detect corruption and trigger reinstall
        # Use shell execution to ensure proper process handling for exec behavior
        local update_output
        update_output=$(assert_command_succeeds "Update should handle corruption by reinstalling" -- \
            "$SHELL" -c "./scripts/claude-toolkit.sh update" 2>&1)
        
        # Should show corruption detection and reinstall
        assert_contains "Repository at ~/.local/share/claude-toolkit is invalid or corrupted" "$update_output" "Should detect repository corruption"
        assert_contains "Reinstalling Claude Toolkit" "$update_output" "Should show reinstall process"
        assert_contains "Claude Toolkit installed" "$update_output" "Should show successful reinstall"
        
        # Verify reinstall worked
        assert_directory_exists "$install_dir" "Install directory should exist after reinstall"
        assert_directory_exists "$install_dir/.git" "Install directory should be a git repository after reinstall"
    )
}

test_update_dry_run() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # First install Claude Toolkit
        local install_output
        install_output=$(assert_command_succeeds "Installation should succeed before dry-run update" -- \
            "./scripts/claude-toolkit.sh" install 2>&1)
        
        # Test dry-run update
        local dry_run_output
        dry_run_output=$(assert_command_succeeds "Dry-run update should succeed" -- \
            "./scripts/claude-toolkit.sh" update --dry-run 2>&1)
        
        assert_contains "dryrun:update_toolkit" "$dry_run_output" "Should show dry-run indicator"
        
        # Verify nothing was actually updated in dry-run mode
        local install_dir="$XDG_DATA_HOME/claude-toolkit"
        assert_directory_exists "$install_dir" "Install directory should still exist after dry-run"
        assert_directory_exists "$install_dir/.git" "Install directory should still be a git repository after dry-run"
    )
}

test_update_with_network_failure() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # First install Claude Toolkit
        local install_output
        install_output=$(assert_command_succeeds "Installation should succeed before network failure test" -- \
            "./scripts/claude-toolkit.sh" install 2>&1)
        
        local install_dir="$XDG_DATA_HOME/claude-toolkit"
        
        # Generate a random invalid URL using library function
        local invalid_url="$(generate_random_site)/repo.git"
        git -C "$install_dir" remote set-url origin "$invalid_url"
        
        # Update should fail due to network error
        local update_output
        update_output=$(assert_command_fails "Update should fail with invalid remote" -- \
            "./scripts/claude-toolkit.sh" update 2>&1) || true
        
        assert_contains "Updating Claude Toolkit" "$update_output" "Should show updating message"
        # The exact error message may vary, but it should fail
        assert_not_contains "Claude Toolkit updated" "$update_output" "Should not show success message on failure"
    )
}

test_update_https_option() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # Install with HTTPS option first
        local install_output
        install_output=$(assert_command_succeeds "Installation with HTTPS should succeed" -- \
            "./scripts/claude-toolkit.sh" install --https 2>&1)
        
        # Create a simulated change in the upstream repository
        local current_dir=$(pwd)
        cd "$upstream_repo_sandbox_dir/upstream-repo"
        echo "# HTTPS update test" >> README.md
        git add README.md
        git commit -m "HTTPS update test commit" >/dev/null 2>&1
        cd "$current_dir"
        
        # Test update with HTTPS option
        local update_output
        update_output=$(assert_command_succeeds "Update with HTTPS should succeed" -- \
            "./scripts/claude-toolkit.sh" update --https 2>&1)
        
        assert_contains "Updating Claude Toolkit" "$update_output" "Should show updating message"
        assert_contains "use_https=true" "$update_output" "Should show HTTPS indicator"
        assert_contains "Claude Toolkit updated" "$update_output" "Should show success message"
        
        # Verify the update was actually pulled
        local install_dir="$XDG_DATA_HOME/claude-toolkit"
        assert_file_contains "$install_dir/README.md" "HTTPS update test" "Updated content should be present after HTTPS update"
    )
}

test_update_preserves_symlinks() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # First install Claude Toolkit
        local install_output
        install_output=$(assert_command_succeeds "Installation should succeed before symlink test" -- \
            "./scripts/claude-toolkit.sh" install 2>&1)
        
        local bin_dir="$XDG_BIN_DIR"
        local install_dir="$XDG_DATA_HOME/claude-toolkit"
        
        # Verify symlinks exist before update
        assert_symlink_exists "$bin_dir/claude-toolkit" "claude-toolkit symlink should exist before update"
        assert_symlink_exists "$bin_dir/claude-code" "claude-code symlink should exist before update"
        assert_symlink_exists "$bin_dir/claude-slash" "claude-slash symlink should exist before update"
        
        # Store symlink targets for comparison
        local toolkit_target=$(readlink "$bin_dir/claude-toolkit")
        local code_target=$(readlink "$bin_dir/claude-code")
        local slash_target=$(readlink "$bin_dir/claude-slash")
        
        # Create a simulated change in the upstream repository
        local current_dir=$(pwd)
        cd "$upstream_repo_sandbox_dir/upstream-repo"
        echo "# Symlink preservation test" >> README.md
        git add README.md
        git commit -m "Symlink preservation test commit" >/dev/null 2>&1
        cd "$current_dir"
        
        # Update should preserve symlinks
        local update_output
        update_output=$(assert_command_succeeds "Update should preserve symlinks" -- \
            "./scripts/claude-toolkit.sh" update 2>&1)
        
        # Verify symlinks are still intact and point to correct locations
        assert_symlink_exists "$bin_dir/claude-toolkit" "claude-toolkit symlink should exist after update"
        assert_symlink_exists "$bin_dir/claude-code" "claude-code symlink should exist after update"
        assert_symlink_exists "$bin_dir/claude-slash" "claude-slash symlink should exist after update"
        
        # Verify symlink targets are preserved
        local new_toolkit_target=$(readlink "$bin_dir/claude-toolkit")
        local new_code_target=$(readlink "$bin_dir/claude-code")
        local new_slash_target=$(readlink "$bin_dir/claude-slash")
        
        assert_equals "$toolkit_target" "$new_toolkit_target" "claude-toolkit symlink target should be preserved"
        assert_equals "$code_target" "$new_code_target" "claude-code symlink target should be preserved"
        assert_equals "$slash_target" "$new_slash_target" "claude-slash symlink target should be preserved"
    )
}

test_update_exec_behavior() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # First install Claude Toolkit
        local install_output
        install_output=$(assert_command_succeeds "Installation should succeed before exec test" -- \
            "./scripts/claude-toolkit.sh" install 2>&1)
        
        # Create a change that adds a detectable marker to the script
        local current_dir=$(pwd)
        cd "$upstream_repo_sandbox_dir/upstream-repo"
        
        # Add a marker to the script that we can detect was executed
        echo '# TEST_MARKER_FOR_EXEC_VALIDATION' >> scripts/claude-toolkit.sh
        git add scripts/claude-toolkit.sh
        git commit -m "Add exec validation marker" >/dev/null 2>&1
        cd "$current_dir"
        
        # Update should succeed and exec to the updated validation
        local update_output
        update_output=$(assert_command_succeeds "Update should succeed with exec validation" -- \
            "./scripts/claude-toolkit.sh" update 2>&1)
        
        assert_contains "Updating Claude Toolkit" "$update_output" "Should show updating message"
        assert_contains "Claude Toolkit updated" "$update_output" "Should show success message"
        assert_contains "Claude Toolkit validated, everything looks OK" "$update_output" "Should show validation success from exec"
        
        # Verify the updated script contains the marker
        local install_dir="$XDG_DATA_HOME/claude-toolkit"
        assert_file_contains "$install_dir/scripts/claude-toolkit.sh" "TEST_MARKER_FOR_EXEC_VALIDATION" "Updated script should contain the test marker"
    )
}

# Register all test functions
register_tests \
    "test_update_comprehensive_functionality" \
    "test_update_when_not_installed" \
    "test_update_with_corrupted_repository" \
    "test_update_dry_run" \
    "test_update_with_network_failure" \
    "test_update_https_option" \
    "test_update_preserves_symlinks" \
    "test_update_exec_behavior"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "Claude Toolkit Update Tests" "$@"
fi
