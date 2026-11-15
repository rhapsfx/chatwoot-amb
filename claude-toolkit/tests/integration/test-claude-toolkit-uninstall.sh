#!/bin/bash
# test-claude-toolkit-uninstall.sh - Tests "scripts/claude-toolkit.sh uninstall" functionality
# 
# Purpose: Test "scripts/claude-toolkit.sh uninstall" functionality with real uninstallation workflow
# Dependencies: None (no shared installation utils - tests genuine uninstall commands only)
# Approach: Use real uninstall command invocations with copied upstream repository in isolated sandboxes

source "$(dirname "$0")/../utils/test-harness.sh"
source "$(dirname "$0")/../utils/upstream-repo-utils.sh"

export DEBUG=true

# Standard test suite setup function for upstream repository tests
test_suite_setup() {
    setup_upstream_repository
}

# Standard test suite teardown function for upstream repository tests
test_suite_teardown() {
    cleanup_upstream_repository
}

test_uninstall_comprehensive_functionality() {
    (
        create_sandbox

        setup_fake_all_shells

        # First install Claude Toolkit to have something to uninstall
        local install_output
        install_output=$(assert_command_succeeds "Installation should succeed before uninstall" -- \
            "./scripts/claude-toolkit.sh" install 2>&1)
        
        # Verify installation was successful
        local install_dir="$XDG_DATA_HOME/claude-toolkit"
        local bin_dir="$XDG_BIN_DIR"
        
        assert_directory_exists "$install_dir" "Install directory should exist before uninstall"
        assert_symlink_exists "$bin_dir/claude-toolkit" "claude-toolkit symlink should exist before uninstall"
        assert_symlink_exists "$bin_dir/claude-code" "claude-code symlink should exist before uninstall"
        assert_symlink_exists "$bin_dir/claude-slash" "claude-slash symlink should exist before uninstall"
        assert_symlink_exists "$bin_dir/claude-template-sources" "claude-template-sources symlink should exist before uninstall"
        
        # Test uninstall with --yes flag to avoid interactive prompt
        local uninstall_output
        uninstall_output=$(assert_command_succeeds "Uninstall should succeed" -- \
            "./scripts/claude-toolkit.sh" uninstall --yes 2>&1)
        
        # Verify uninstallation removed all components
        assert_directory_not_exists "$install_dir" "Install directory should be removed"
        assert_file_not_exists "$bin_dir/claude-toolkit" "claude-toolkit symlink should be removed"
        assert_file_not_exists "$bin_dir/claude-code" "claude-code symlink should be removed"
        assert_file_not_exists "$bin_dir/claude-slash" "claude-slash symlink should be removed"
        assert_file_not_exists "$bin_dir/claude-template-sources" "claude-template-sources symlink should be removed"
        
        # Verify shell configurations were cleaned up (script-specific blocks only)
        local script_marker_start="# >>> claude-toolkit.sh start >>>"
        local script_marker_end="# <<< claude-toolkit.sh end <<<"
        
        # Check bash profile cleanup
        if [[ -f "$sandbox_dir/.bash_profile" ]]; then
            local bash_profile_content=$(cat "$sandbox_dir/.bash_profile")
            assert_not_contains "$script_marker_start" "$bash_profile_content" "Bash config should not contain script markers after uninstall"
        fi
        
        # Check zsh config cleanup
        if [[ -f "$sandbox_dir/.zshrc" ]]; then
            local zshrc_content=$(cat "$sandbox_dir/.zshrc")
            assert_not_contains "$script_marker_start" "$zshrc_content" "Zsh config should not contain script markers after uninstall"
        fi
        
        # Check fish config cleanup
        if [[ -f "$sandbox_dir/.config/fish/config.fish" ]]; then
            local fish_config_content=$(cat "$sandbox_dir/.config/fish/config.fish")
            assert_not_contains "$script_marker_start" "$fish_config_content" "Fish config should not contain script markers after uninstall"
        fi
        
        # Verify uninstall output contains expected messages
        assert_contains "Uninstalling Claude Toolkit" "$uninstall_output" "Should show uninstallation message"
        assert_contains "Claude Toolkit uninstalled" "$uninstall_output" "Should show success message"
    )
}

test_uninstall_with_bash_shell() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # Install first with bash shell
        local install_output
        install_output=$(assert_command_succeeds "Install with bash shell should succeed" -- \
            "./scripts/claude-toolkit.sh" install --shell=bash 2>&1)
        
        # Uninstall with bash shell specified
        local uninstall_output
        uninstall_output=$(assert_command_succeeds "Uninstall with bash shell should succeed" -- \
            "./scripts/claude-toolkit.sh" uninstall --shell=bash --yes 2>&1)
        
        assert_contains "Uninstalling Claude Toolkit" "$uninstall_output" "Should show uninstallation message"
        assert_contains "shell=bash" "$uninstall_output" "Should show selected shell"
        assert_contains "Claude Toolkit uninstalled" "$uninstall_output" "Should show success message"
        
        # Verify components are removed
        assert_directory_not_exists "$XDG_DATA_HOME/claude-toolkit" "Install directory should be removed"
        assert_file_not_exists "$XDG_BIN_DIR/claude-toolkit" "claude-toolkit symlink should be removed"
    )
}

test_uninstall_when_not_installed() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # Try to uninstall when nothing is installed
        local uninstall_output
        uninstall_output=$(assert_command_succeeds "Uninstall should succeed even when not installed" -- \
            "./scripts/claude-toolkit.sh" uninstall --yes 2>&1)
        
        assert_contains "Claude Toolkit is not installed" "$uninstall_output" "Should detect no installation"
    )
}

test_uninstall_partial_installation() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # Create partial installation state (symlinks but no directory)
        local bin_dir="$XDG_BIN_DIR"
        mkdir -p "$bin_dir"
        ln -s "../share/claude-toolkit/scripts/claude-code.sh" "$bin_dir/claude-code"
        ln -s "../share/claude-toolkit/scripts/claude-slash.sh" "$bin_dir/claude-slash"
        
        # Test uninstall handles partial state
        local uninstall_output
        uninstall_output=$(assert_command_succeeds "Uninstall should handle partial installation" -- \
            "./scripts/claude-toolkit.sh" uninstall --yes 2>&1)
        
        assert_contains "Uninstalling Claude Toolkit" "$uninstall_output" "Should show uninstallation message"
        assert_contains "Claude Toolkit uninstalled" "$uninstall_output" "Should show success message"
        
        # Verify symlinks are cleaned up
        assert_file_not_exists "$bin_dir/claude-code" "claude-code symlink should be removed"
        assert_file_not_exists "$bin_dir/claude-slash" "claude-slash symlink should be removed"
    )
}

test_uninstall_dry_run() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # Install first
        local install_output
        install_output=$(assert_command_succeeds "Installation should succeed before dry-run uninstall" -- \
            "./scripts/claude-toolkit.sh" install 2>&1)
        
        # Test dry-run uninstall
        local dry_run_output
        dry_run_output=$(assert_command_succeeds "Dry-run uninstall should succeed" -- \
            "./scripts/claude-toolkit.sh" uninstall --dry-run 2>&1)
        
        assert_contains "dryrun:uninstall_toolkit" "$dry_run_output" "Should show dry-run indicator"
        
        # Verify nothing was actually removed in dry-run mode
        assert_directory_exists "$XDG_DATA_HOME/claude-toolkit" "Install directory should still exist after dry-run"
        assert_file_exists "$XDG_BIN_DIR/claude-toolkit" "claude-toolkit symlink should still exist after dry-run"
        assert_file_exists "$XDG_BIN_DIR/claude-code" "claude-code symlink should still exist after dry-run"
        assert_file_exists "$XDG_BIN_DIR/claude-slash" "claude-slash symlink should still exist after dry-run"
    )
}

test_uninstall_interactive_cancellation() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # Install first
        local install_output
        install_output=$(assert_command_succeeds "Installation should succeed before interactive uninstall" -- \
            "./scripts/claude-toolkit.sh" install 2>&1)
        
        # Test interactive uninstall with "no" response
        local uninstall_output
        uninstall_output=$(echo "n" | assert_command_fails "Interactive uninstall should be cancelled" -- \
            "./scripts/claude-toolkit.sh" uninstall 2>&1) || true
        
        assert_contains "Proceed with uninstall? [y/N]:" "$uninstall_output" "Should show interactive prompt"
        assert_contains "Uninstall cancelled by user" "$uninstall_output" "Should show cancellation message"
        
        # Verify nothing was removed after cancellation
        assert_directory_exists "$XDG_DATA_HOME/claude-toolkit" "Install directory should still exist after cancellation"
        assert_file_exists "$XDG_BIN_DIR/claude-toolkit" "claude-toolkit symlink should still exist after cancellation"
    )
}

test_uninstall_interactive_confirmation() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # Install first
        local install_output
        install_output=$(assert_command_succeeds "Installation should succeed before interactive uninstall" -- \
            "./scripts/claude-toolkit.sh" install 2>&1)
        
        # Test interactive uninstall with "yes" response
        local uninstall_output
        uninstall_output=$(echo "y" | assert_command_succeeds "Interactive uninstall should succeed with confirmation" -- \
            "./scripts/claude-toolkit.sh" uninstall 2>&1)
        
        assert_contains "Proceed with uninstall? [y/N]:" "$uninstall_output" "Should show interactive prompt"
        assert_contains "Proceeding with uninstall" "$uninstall_output" "Should show proceed message"
        assert_contains "Claude Toolkit uninstalled" "$uninstall_output" "Should show success message"
        
        # Verify components were removed after confirmation
        assert_directory_not_exists "$XDG_DATA_HOME/claude-toolkit" "Install directory should be removed after confirmation"
        assert_file_not_exists "$XDG_BIN_DIR/claude-toolkit" "claude-toolkit symlink should be removed after confirmation"
    )
}

# Register all test functions
register_tests \
    "test_uninstall_comprehensive_functionality" \
    "test_uninstall_with_bash_shell" \
    "test_uninstall_when_not_installed" \
    "test_uninstall_partial_installation" \
    "test_uninstall_dry_run" \
    "test_uninstall_interactive_cancellation" \
    "test_uninstall_interactive_confirmation"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "Claude Toolkit Uninstall Tests" "$@"
fi
