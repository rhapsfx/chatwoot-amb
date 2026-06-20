#!/bin/bash
# test-claude-toolkit-install.sh - Tests "scripts/claude-toolkit.sh install" functionality
# 
# Purpose: Test "scripts/claude-toolkit.sh install" functionality with real installation workflow
# Dependencies: None (no shared installation utils - tests genuine install commands only)
# Approach: Use real install command invocations with copied upstream repository in isolated sandboxes

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

test_install_comprehensive_functionality() {
    (
        create_sandbox

        setup_fake_all_shells

        # Test real installation workflow
        local install_output
        install_output=$(assert_command_succeeds "Installation should succeed" -- \
            "./scripts/claude-toolkit.sh" install 2>&1)
        
        # Verify installation created proper directory structure
        local install_dir="$XDG_DATA_HOME/claude-toolkit"
        local bin_dir="$XDG_BIN_DIR"
        
        assert_directory_exists "$install_dir" "Install directory should exist"
        assert_directory_exists "$install_dir/.git" "Install directory should be a git repository"
        assert_directory_exists "$install_dir/scripts" "Scripts directory should exist"
        assert_directory_exists "$bin_dir" "Bin directory should exist"
        
        # Verify required scripts exist in installed repository
        assert_file_exists "$install_dir/scripts/claude-toolkit.sh" "claude-toolkit.sh should exist"
        assert_file_exists "$install_dir/scripts/claude-code.sh" "claude-code.sh should exist"
        assert_file_exists "$install_dir/scripts/claude-slash.sh" "claude-slash.sh should exist"
        assert_file_executable "$install_dir/scripts/claude-toolkit.sh" "claude-toolkit.sh should be executable"
        assert_file_executable "$install_dir/scripts/claude-code.sh" "claude-code.sh should be executable"
        assert_file_executable "$install_dir/scripts/claude-slash.sh" "claude-slash.sh should be executable"
        
        # Verify symlinks were created
        assert_symlink_exists "$bin_dir/claude-toolkit" "claude-toolkit symlink should exist"
        assert_symlink_exists "$bin_dir/claude-code" "claude-code symlink should exist"
        assert_symlink_exists "$bin_dir/claude-slash" "claude-slash symlink should exist"
        assert_symlink_exists "$bin_dir/claude-template-sources" "claude-template-sources symlink should exist"
        
        # Verify XDG paths are set correctly in sandbox
        assert_equals "$sandbox_dir/.local/share" "$XDG_DATA_HOME" "XDG_DATA_HOME should be set correctly"
        assert_equals "$sandbox_dir/.local/bin" "$XDG_BIN_DIR" "XDG_BIN_DIR should be set correctly"
        
        # Verify shell configuration was updated
        local xdg_marker_start="# >>> xdg-user-bin start >>>"
        local xdg_marker_end="# <<< xdg-user-bin end <<<"
        local script_marker_start="# >>> claude-toolkit.sh start >>>"
        local script_marker_end="# <<< claude-toolkit.sh end <<<"
        
        assert_file_exists "$sandbox_dir/.bash_profile" "Bash profile should exist"
        local bash_profile_content=$(cat "$sandbox_dir/.bash_profile")
        assert_contains "$xdg_marker_start" "$bash_profile_content" "Bash config should contain XDG PATH markers"
        assert_contains "$xdg_marker_end" "$bash_profile_content" "Bash config should contain XDG PATH end marker"
        assert_contains "$script_marker_start" "$bash_profile_content" "Bash config should contain script markers"
        assert_contains "$script_marker_end" "$bash_profile_content" "Bash config should contain script end marker"
        
        assert_file_exists "$sandbox_dir/.zshrc" "Zsh config should exist"
        local zshrc_content=$(cat "$sandbox_dir/.zshrc")
        assert_contains "$xdg_marker_start" "$zshrc_content" "Zsh config should contain XDG PATH markers"
        assert_contains "$script_marker_start" "$zshrc_content" "Zsh config should contain script markers"
        
        assert_file_exists "$sandbox_dir/.config/fish/config.fish" "Fish config should exist"
        local fish_config_content=$(cat "$sandbox_dir/.config/fish/config.fish")
        assert_contains "$xdg_marker_start" "$fish_config_content" "Fish config should contain XDG PATH markers"
        assert_contains "$script_marker_start" "$fish_config_content" "Fish config should contain script markers"
        assert_contains "set -gx PATH" "$fish_config_content" "Fish config should use proper PATH export syntax"
        
        # Verify installation output contains expected messages
        assert_contains "Installing Claude Toolkit" "$install_output" "Should show installation message"
        assert_contains "Claude Toolkit installed" "$install_output" "Should show success message"
    )
}

test_install_with_bash_shell() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # Test installation with bash shell parameter
        local install_output
        install_output=$(assert_command_succeeds "Installation with bash shell should succeed" -- \
            "./scripts/claude-toolkit.sh" install --shell=bash 2>&1)
        
        assert_contains "Installing Claude Toolkit" "$install_output" "Should show installation message"
        assert_contains "shell=bash" "$install_output" "Should show selected shell"
        assert_contains "Claude Toolkit installed" "$install_output" "Should show success message"
        
        # Verify only bash shell was configured
        assert_file_exists "$sandbox_dir/.bash_profile" "Bash profile should exist"
        local bash_content=$(cat "$sandbox_dir/.bash_profile")
        assert_contains "# >>> claude-toolkit.sh start >>>" "$bash_content" "Bash config should be updated with --shell=bash"
    )
}

test_install_with_zsh_shell() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # Test installation with zsh shell parameter
        local install_output
        install_output=$(assert_command_succeeds "Installation with zsh shell should succeed" -- \
            "./scripts/claude-toolkit.sh" install --shell=zsh 2>&1)
        
        assert_contains "Installing Claude Toolkit" "$install_output" "Should show installation message for zsh"
        assert_contains "shell=zsh" "$install_output" "Should show selected shell"
        assert_contains "Claude Toolkit installed" "$install_output" "Should show success message"
        
        # Verify zsh shell was configured
        assert_file_exists "$sandbox_dir/.zshrc" "Zsh config should exist"
        local zsh_content=$(cat "$sandbox_dir/.zshrc")
        assert_contains "# >>> claude-toolkit.sh start >>>" "$zsh_content" "Zsh config should be updated with --shell=zsh"
    )
}

test_install_with_fish_shell() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # Test installation with fish shell parameter
        local install_output
        install_output=$(assert_command_succeeds "Installation with fish shell should succeed" -- \
            "./scripts/claude-toolkit.sh" install --shell=fish 2>&1)
        
        assert_contains "Installing Claude Toolkit" "$install_output" "Should show installation message for fish"
        assert_contains "Claude Toolkit installed" "$install_output" "Should show success message"
        
        # Verify fish shell was configured
        assert_file_exists "$sandbox_dir/.config/fish/config.fish" "Fish config should exist"
        local fish_content=$(cat "$sandbox_dir/.config/fish/config.fish")
        assert_contains "# >>> claude-toolkit.sh start >>>" "$fish_content" "Fish config should be updated with --shell=fish"
        assert_contains "set -gx PATH" "$fish_content" "Fish config should use proper PATH export syntax"
    )
}

test_install_https_option() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # Test that --https option is parsed correctly
        # Since we're using the local upstream repository, --https should still work
        local install_output
        install_output=$(assert_command_succeeds "HTTPS option should be accepted" -- \
            "./scripts/claude-toolkit.sh" install --https 2>&1)
        
        assert_contains "Installing Claude Toolkit" "$install_output" "Should show installation message"
        assert_contains "use_https=true" "$install_output" "Should show https indicator"

        # Note: The --https flag affects the default repository URL selection,
        # but since we override DEFAULT_REMOTE_REPOSITORY_HTTPS with local path,
        # the actual cloning should still work with our local upstream repo
        
        # Verify installation completed successfully
        assert_directory_exists "$XDG_DATA_HOME/claude-toolkit" "Install directory should exist"
        assert_symlink_exists "$XDG_BIN_DIR/claude-toolkit" "claude-toolkit symlink should exist"
        assert_symlink_exists "$XDG_BIN_DIR/claude-template-sources" "claude-template-sources symlink should exist"
    )
}

test_install_idempotency() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # First installation
        local first_output
        first_output=$(assert_command_succeeds "First install should succeed" -- \
            "./scripts/claude-toolkit.sh" install 2>&1)
        
        assert_contains "Installing Claude Toolkit" "$first_output" "Should show installation message"
        assert_contains "Claude Toolkit installed" "$first_output" "Should show success message"
        
        # Verify first installation completed
        assert_directory_exists "$XDG_DATA_HOME/claude-toolkit" "Install directory should exist after first install"
        assert_symlink_exists "$XDG_BIN_DIR/claude-toolkit" "claude-toolkit symlink should exist after first install"
        
        # Second installation should detect existing installation
        local second_output
        second_output=$(assert_command_succeeds "Second install should also succeed" -- \
            "./scripts/claude-toolkit.sh" install 2>&1)
        
        assert_contains "Claude Toolkit is already installed" "$second_output" "Should detect existing installation"
        
        # Installation should still be valid after second attempt
        assert_directory_exists "$XDG_DATA_HOME/claude-toolkit" "Install directory should still exist after second install"
        assert_symlink_exists "$XDG_BIN_DIR/claude-toolkit" "claude-toolkit symlink should still exist after second install"
    )
}

test_install_url_retry_with_nonexistent_repositories() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # Generate random nonexistent URLs for testing
        local random_site1 random_site2
        random_site1=$(generate_random_site)
        random_site2=$(generate_random_site)
        local ssh_url="git@${random_site1#https://}:test/repo.git"
        local https_url="${random_site2}/test/repo.git"

        # Test with nonexistent repositories to verify retry logic
        # The installation will continue despite clone failures (creates symlinks, etc.)
        # Use invalid script_root_dir to force remote clone path instead of local repo detection
        local invalid_root_dir="/tmp/nonexistent-$(generate_uuid)"
        local install_output
        install_output=$(script_root_dir="$invalid_root_dir" assert_command_succeeds "Install should complete despite clone failures" -- \
            "./scripts/claude-toolkit.sh" install --remote-repository "$ssh_url,$https_url" --debug 2>&1)
        
        # Should show attempts for both URLs
        assert_contains "Attempting to clone from: $ssh_url" "$install_output" "Should attempt SSH URL first"
        assert_contains "Clone failed, trying next method..." "$install_output" "Should show fallback message"
        assert_contains "Attempting to clone from: $https_url" "$install_output" "Should attempt HTTPS URL second"
        assert_contains "Failed to clone repository using any of the provided URLs" "$install_output" "Should show final failure message"
        
        # Should list all attempted URLs in error output
        assert_contains "Attempted: $ssh_url" "$install_output" "Should list SSH URL in attempts"
        assert_contains "Attempted: $https_url" "$install_output" "Should list HTTPS URL in attempts"
    )
}

test_install_url_retry_https_first() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # Generate random nonexistent URLs for testing
        local random_site1 random_site2
        random_site1=$(generate_random_site)
        random_site2=$(generate_random_site)
        local ssh_url="git@${random_site1#https://}:test/repo.git"
        local https_url="${random_site2}/test/repo.git"

        # Test --https flag affects URL order when no --remote-repository specified
        # Use invalid script_root_dir to force remote clone path instead of local repo detection
        local invalid_root_dir="/tmp/nonexistent-$(generate_uuid)"
        local install_output
        install_output=$(script_root_dir="$invalid_root_dir" assert_command_succeeds "Install should complete despite clone failures" -- \
            "./scripts/claude-toolkit.sh" install --https --debug \
            --remote-repository "$https_url,$ssh_url" 2>&1)
        
        # With explicit --remote-repository, should use user's order (HTTPS first)
        assert_contains "Attempting to clone from: $https_url" "$install_output" "Should attempt HTTPS URL first when specified first"
        assert_contains "Clone failed, trying next method..." "$install_output" "Should show fallback message"
        assert_contains "Attempting to clone from: $ssh_url" "$install_output" "Should attempt SSH URL second when specified second"
    )
}

test_install_single_url_no_fallback() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # Generate random nonexistent URL for testing
        local random_site
        random_site=$(generate_random_site)
        local single_url="$random_site/single/repo.git"

        # Test with single nonexistent URL - should not show fallback behavior
        # Use invalid script_root_dir to force remote clone path instead of local repo detection
        local invalid_root_dir="/tmp/nonexistent-$(generate_uuid)"
        local install_output
        install_output=$(script_root_dir="$invalid_root_dir" assert_command_succeeds "Install should complete despite single URL clone failure" -- \
            "./scripts/claude-toolkit.sh" install --remote-repository "$single_url" --debug 2>&1)
        
        # Should attempt only the single URL
        assert_contains "Attempting to clone from: $single_url" "$install_output" "Should attempt the single URL"
        assert_not_contains "trying next method" "$install_output" "Should not show fallback message with single URL"
        assert_contains "Failed to clone repository using any of the provided URLs" "$install_output" "Should show failure message"
        assert_contains "Attempted: $single_url" "$install_output" "Should list the single attempted URL"
    )
}

test_install_comma_separated_url_parsing() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # Generate random nonexistent URLs for testing
        local random_site1 random_site2 random_site3
        random_site1=$(generate_random_site)
        random_site2=$(generate_random_site)
        random_site3=$(generate_random_site)
        local url1="git@${random_site1#https://}:test/repo.git"
        local url2="${random_site2}/test/repo.git"
        local url3="ssh://${random_site3#https://}/test/repo.git"

        # Test comma-separated URL parsing with spaces
        # Use invalid script_root_dir to force remote clone path instead of local repo detection
        local invalid_root_dir="/tmp/nonexistent-$(generate_uuid)"
        local install_output
        install_output=$(script_root_dir="$invalid_root_dir" assert_command_succeeds "Install should parse comma-separated URLs with spaces and complete" -- \
            "./scripts/claude-toolkit.sh" install \
            --remote-repository "$url1, $url2 , $url3" \
            --debug 2>&1)
        
        # Should parse and trim whitespace from each URL
        assert_contains "$url1 $url2 $url3" "$install_output" "Should parse comma-separated URLs and trim spaces"
        assert_contains "Attempting to clone from: $url1" "$install_output" "Should attempt first URL"
        assert_contains "Attempting to clone from: $url2" "$install_output" "Should attempt second URL"
        assert_contains "Attempting to clone from: $url3" "$install_output" "Should attempt third URL"
    )
}

# Register all test functions
register_tests \
    "test_install_comprehensive_functionality" \
    "test_install_with_bash_shell" \
    "test_install_with_zsh_shell" \
    "test_install_with_fish_shell" \
    "test_install_https_option" \
    "test_install_idempotency" \
    "test_install_url_retry_with_nonexistent_repositories" \
    "test_install_url_retry_https_first" \
    "test_install_single_url_no_fallback" \
    "test_install_comma_separated_url_parsing"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "Claude Toolkit Installation Tests" "$@"
fi
