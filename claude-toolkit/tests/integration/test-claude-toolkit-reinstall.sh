#!/bin/bash
# test-claude-toolkit-reinstall.sh - Tests "scripts/claude-toolkit.sh reinstall" functionality
# 
# Purpose: Test "scripts/claude-toolkit.sh reinstall" end-to-end behavior and outcomes
# Dependencies: None (no shared installation utils - tests genuine reinstall commands only)  
# Approach: Test reinstall command completion and verify correct final state

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

test_reinstall_basic_functionality() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # First, install Claude Toolkit normally
        assert_command_succeeds "Initial installation should succeed" -- \
            "./scripts/claude-toolkit.sh" install >/dev/null 2>&1
        
        # Verify installation exists
        local install_dir="$XDG_DATA_HOME/claude-toolkit"
        assert_directory_exists "$install_dir" "Install directory should exist after initial install"
        assert_directory_exists "$install_dir/.git" "Install directory should be a git repository"
        
        # Create a marker file to verify reinstall actually removes/recreates
        echo "test-marker" > "$install_dir/test-marker.txt"
        assert_file_exists "$install_dir/test-marker.txt" "Marker file should exist before reinstall"
        
        # Now test actual reinstall command
        assert_command_succeeds "Reinstall should succeed" -- \
            "./scripts/claude-toolkit.sh" reinstall >/dev/null 2>&1
        
        # Verify installation directory exists and is valid after reinstall
        assert_directory_exists "$install_dir" "Install directory should exist after reinstall"
        assert_directory_exists "$install_dir/.git" "Git directory should exist after reinstall" 
        assert_file_exists "$install_dir/scripts/claude-toolkit.sh" "claude-toolkit.sh should exist after reinstall"
        
        # Verify symlinks exist
        local bin_dir="$XDG_BIN_DIR"
        assert_symlink_exists "$bin_dir/claude-toolkit" "claude-toolkit symlink should exist after reinstall"
        assert_symlink_exists "$bin_dir/claude-code" "claude-code symlink should exist after reinstall"
        assert_symlink_exists "$bin_dir/claude-slash" "claude-slash symlink should exist after reinstall"
        assert_symlink_exists "$bin_dir/claude-template-sources" "claude-template-sources symlink should exist after reinstall"
        
        # Verify marker file was removed by reinstall (proves it actually reinstalled)
        assert_file_not_exists "$install_dir/test-marker.txt" "Marker file should be removed by reinstall"
    )
}

test_reinstall_with_shell_parameter() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # First, install Claude Toolkit
        assert_command_succeeds "Initial installation should succeed" -- \
            "./scripts/claude-toolkit.sh" install >/dev/null 2>&1
        
        local install_dir="$XDG_DATA_HOME/claude-toolkit"
        assert_directory_exists "$install_dir" "Install directory should exist after initial install"
        
        # Now reinstall with specific shell parameter
        assert_command_succeeds "Reinstall with shell parameter should succeed" -- \
            "./scripts/claude-toolkit.sh" reinstall --shell=zsh >/dev/null 2>&1
        
        # Verify installation structure after reinstall
        assert_directory_exists "$install_dir" "Install directory should exist after reinstall"
        assert_directory_exists "$install_dir/.git" "Git directory should exist after reinstall"
        assert_file_exists "$install_dir/scripts/claude-toolkit.sh" "claude-toolkit.sh should exist after reinstall"
        
        # Verify zsh configuration was updated during reinstall
        assert_file_exists "$sandbox_dir/.zshrc" "Zsh config should exist after reinstall with --shell=zsh"
        local zsh_content=$(cat "$sandbox_dir/.zshrc")
        assert_contains "# >>> claude-toolkit.sh start >>>" "$zsh_content" "Zsh config should be updated during reinstall"
    )
}

test_reinstall_with_https_option() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # First, install Claude Toolkit
        assert_command_succeeds "Initial installation should succeed" -- \
            "./scripts/claude-toolkit.sh" install >/dev/null 2>&1
        
        local install_dir="$XDG_DATA_HOME/claude-toolkit"
        assert_directory_exists "$install_dir" "Install directory should exist after initial install"
        
        # Test reinstall with --https option
        assert_command_succeeds "Reinstall with HTTPS option should succeed" -- \
            "./scripts/claude-toolkit.sh" reinstall --https >/dev/null 2>&1
        
        # Verify installation completed successfully after reinstall
        assert_directory_exists "$install_dir" "Install directory should exist after reinstall"
        assert_directory_exists "$install_dir/.git" "Git directory should exist after reinstall"
        assert_symlink_exists "$XDG_BIN_DIR/claude-toolkit" "claude-toolkit symlink should exist after reinstall"
    )
}

test_reinstall_with_missing_installation() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # Test reinstall when no installation exists - should work like install
        local install_dir="$XDG_DATA_HOME/claude-toolkit"
        assert_directory_not_exists "$install_dir" "Install directory should not exist initially"
        
        # Test actual reinstall without existing installation
        assert_command_succeeds "Reinstall without installation should succeed" -- \
            "./scripts/claude-toolkit.sh" reinstall >/dev/null 2>&1
        
        # Verify installation was created
        assert_directory_exists "$install_dir" "Install directory should exist after reinstall"
        assert_directory_exists "$install_dir/.git" "Git directory should exist after reinstall"
        assert_file_exists "$install_dir/scripts/claude-toolkit.sh" "claude-toolkit.sh should exist after reinstall"
        assert_symlink_exists "$XDG_BIN_DIR/claude-toolkit" "claude-toolkit symlink should exist after reinstall"
    )
}

test_reinstall_corrupted_installation_recovery() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # First install normally
        assert_command_succeeds "Initial installation should succeed" -- \
            "./scripts/claude-toolkit.sh" install >/dev/null 2>&1
        
        local install_dir="$XDG_DATA_HOME/claude-toolkit"
        assert_directory_exists "$install_dir" "Install directory should exist after initial install"
        
        # Corrupt the installation by removing git directory
        rm -rf "$install_dir/.git"
        assert_directory_not_exists "$install_dir/.git" "Git directory should be removed"
        
        # Test that reinstall recovers from corruption
        assert_command_succeeds "Reinstall should recover from corrupted installation" -- \
            "./scripts/claude-toolkit.sh" reinstall >/dev/null 2>&1
        
        # Verify the installation was properly restored
        assert_directory_exists "$install_dir" "Install directory should exist after reinstall"
        assert_directory_exists "$install_dir/.git" "Git directory should be restored after reinstall"
        assert_file_exists "$install_dir/scripts/claude-toolkit.sh" "claude-toolkit.sh should exist after reinstall"
        assert_symlink_exists "$XDG_BIN_DIR/claude-toolkit" "claude-toolkit symlink should exist after reinstall"
    )
}

test_reinstall_url_retry_with_nonexistent_repositories() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # Generate random nonexistent URLs for testing
        local random_site1 random_site2
        random_site1=$(generate_random_site)
        random_site2=$(generate_random_site)
        local ssh_url="git@${random_site1#https://}:test/repo.git"
        local https_url="${random_site2}/test/repo.git"

        # First install normally (using default repository)
        assert_command_succeeds "Initial installation should succeed" -- \
            "./scripts/claude-toolkit.sh" install >/dev/null 2>&1
        
        local install_dir="$XDG_DATA_HOME/claude-toolkit"
        assert_directory_exists "$install_dir" "Install directory should exist after initial install"

        # Test reinstall with nonexistent repositories to verify retry logic
        # The reinstall should fail when unable to clone repository (unlike install)
        # Use invalid script_root_dir to force remote clone path instead of local repo detection
        local invalid_root_dir="/tmp/nonexistent-$(generate_uuid)"
        local reinstall_output
        reinstall_output=$(script_root_dir="$invalid_root_dir" assert_command_fails "Reinstall should fail when unable to clone repositories" -- \
            "./scripts/claude-toolkit.sh" reinstall --remote-repository "$ssh_url,$https_url" --debug 2>&1)
        
        # Should show attempts for both URLs
        assert_contains "Attempting to clone from: $ssh_url" "$reinstall_output" "Should attempt SSH URL first"
        assert_contains "Clone failed, trying next method..." "$reinstall_output" "Should show fallback message"
        assert_contains "Attempting to clone from: $https_url" "$reinstall_output" "Should attempt HTTPS URL second"
        assert_contains "Failed to clone repository using any of the provided URLs" "$reinstall_output" "Should show final failure message"
        
        # Should list all attempted URLs in error output
        assert_contains "Attempted: $ssh_url" "$reinstall_output" "Should list SSH URL in attempts"
        assert_contains "Attempted: $https_url" "$reinstall_output" "Should list HTTPS URL in attempts"
    )
}

test_reinstall_url_retry_https_first() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # Generate random nonexistent URLs for testing
        local random_site1 random_site2
        random_site1=$(generate_random_site)
        random_site2=$(generate_random_site)
        local ssh_url="git@${random_site1#https://}:test/repo.git"
        local https_url="${random_site2}/test/repo.git"

        # First install normally (using default repository)
        assert_command_succeeds "Initial installation should succeed" -- \
            "./scripts/claude-toolkit.sh" install >/dev/null 2>&1

        # Test reinstall with explicit --remote-repository (user's order should be preserved)
        # Use invalid script_root_dir to force remote clone path instead of local repo detection
        local invalid_root_dir="/tmp/nonexistent-$(generate_uuid)"
        local reinstall_output
        reinstall_output=$(script_root_dir="$invalid_root_dir" assert_command_fails "Reinstall should fail when unable to clone repositories" -- \
            "./scripts/claude-toolkit.sh" reinstall --https --debug \
            --remote-repository "$https_url,$ssh_url" 2>&1)
        
        # With explicit --remote-repository, should use user's order (HTTPS first)
        assert_contains "Attempting to clone from: $https_url" "$reinstall_output" "Should attempt HTTPS URL first when specified first"
        assert_contains "Clone failed, trying next method..." "$reinstall_output" "Should show fallback message"
        assert_contains "Attempting to clone from: $ssh_url" "$reinstall_output" "Should attempt SSH URL second when specified second"
    )
}

test_reinstall_single_url_no_fallback() {
    (
        create_sandbox
        
        setup_fake_all_shells

        # Generate random nonexistent URL for testing
        local random_site
        random_site=$(generate_random_site)
        local single_url="$random_site/single/repo.git"

        # First install normally (using default repository)
        assert_command_succeeds "Initial installation should succeed" -- \
            "./scripts/claude-toolkit.sh" install >/dev/null 2>&1

        # Test reinstall with single nonexistent URL - should not show fallback behavior
        # Use invalid script_root_dir to force remote clone path instead of local repo detection
        local invalid_root_dir="/tmp/nonexistent-$(generate_uuid)"
        local reinstall_output
        reinstall_output=$(script_root_dir="$invalid_root_dir" assert_command_fails "Reinstall should fail with single URL clone failure" -- \
            "./scripts/claude-toolkit.sh" reinstall --remote-repository "$single_url" --debug 2>&1)
        
        # Should attempt only the single URL
        assert_contains "Attempting to clone from: $single_url" "$reinstall_output" "Should attempt the single URL"
        assert_not_contains "trying next method" "$reinstall_output" "Should not show fallback message with single URL"
        assert_contains "Failed to clone repository using any of the provided URLs" "$reinstall_output" "Should show failure message"
        assert_contains "Attempted: $single_url" "$reinstall_output" "Should list the single attempted URL"
    )
}

test_reinstall_comma_separated_url_parsing() {
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

        # First install normally (using default repository)
        assert_command_succeeds "Initial installation should succeed" -- \
            "./scripts/claude-toolkit.sh" install >/dev/null 2>&1

        # Test reinstall with comma-separated URL parsing with spaces
        # Use invalid script_root_dir to force remote clone path instead of local repo detection
        local invalid_root_dir="/tmp/nonexistent-$(generate_uuid)"
        local reinstall_output
        reinstall_output=$(script_root_dir="$invalid_root_dir" assert_command_fails "Reinstall should fail but parse comma-separated URLs correctly" -- \
            "./scripts/claude-toolkit.sh" reinstall \
            --remote-repository "$url1, $url2 , $url3" \
            --debug 2>&1)
        
        # Should parse and trim whitespace from each URL
        assert_contains "$url1 $url2 $url3" "$reinstall_output" "Should parse comma-separated URLs and trim spaces"
        assert_contains "Attempting to clone from: $url1" "$reinstall_output" "Should attempt first URL"
        assert_contains "Attempting to clone from: $url2" "$reinstall_output" "Should attempt second URL"
        assert_contains "Attempting to clone from: $url3" "$reinstall_output" "Should attempt third URL"
    )
}

# Register all test functions  
register_tests \
    "test_reinstall_basic_functionality" \
    "test_reinstall_with_shell_parameter" \
    "test_reinstall_with_https_option" \
    "test_reinstall_with_missing_installation" \
    "test_reinstall_corrupted_installation_recovery" \
    "test_reinstall_url_retry_with_nonexistent_repositories" \
    "test_reinstall_url_retry_https_first" \
    "test_reinstall_single_url_no_fallback" \
    "test_reinstall_comma_separated_url_parsing"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "Claude Toolkit Reinstall Tests" "$@"
fi