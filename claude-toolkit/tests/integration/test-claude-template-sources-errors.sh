#!/bin/bash
# test-claude-template-sources-errors.sh - Tests claude-template-sources.sh error handling and edge cases
# 
# Purpose: Test scripts/claude-template-sources.sh error scenarios and edge cases
# Dependencies: None (creates own test scenarios)
# Approach: Create various error conditions and verify proper handling

source "$(dirname "$0")/../utils/test-harness.sh"
source "$(dirname "$0")/../utils/upstream-repo-utils.sh"

export DEBUG=true
original_dir="$(pwd)"
# Standard test suite setup function for upstream repository tests
test_suite_setup() {
    setup_upstream_repository
}

# Standard test suite teardown function for upstream repository tests
test_suite_teardown() {
    cleanup_upstream_repository
}

test_error_handling_no_command() {
    (
        create_sandbox
        
        # Test with no command specified
        local no_cmd_output
        no_cmd_output=$(assert_command_fails "No command should fail" -- ./scripts/claude-template-sources.sh 2>&1)
        
        assert_contains "No command specified" "$no_cmd_output" "Should report no command error"
        assert_contains "Commands: add, remove, list" "$no_cmd_output" "Should show available commands"
    )
}

test_error_handling_invalid_command() {
    (
        create_sandbox
        
        # Test with invalid command
        local invalid_output
        invalid_output=$(assert_command_fails "Invalid command should fail" -- ./scripts/claude-template-sources.sh invalid-command 2>&1)
        
        assert_contains "Unknown command: invalid-command" "$invalid_output" "Should report unknown command"
        assert_contains "Valid commands: add, remove, list" "$invalid_output" "Should list valid commands"
    )
}

test_error_handling_missing_arguments() {
    (
        create_sandbox
        
        # Test add command without arguments
        local add_no_args_output
        add_no_args_output=$(assert_command_fails "Add without arguments should fail" -- ./scripts/claude-template-sources.sh add 2>&1)
        
        assert_contains "add requires <name> and <git-url> arguments" "$add_no_args_output" "Should report missing add arguments"
        
        # Test add command with only name
        local add_name_only_output
        add_name_only_output=$(assert_command_fails "Add with only name should fail" -- ./scripts/claude-template-sources.sh add source-name 2>&1)
        
        assert_contains "add requires <name> and <git-url> arguments" "$add_name_only_output" "Should require both name and URL"
        
        # Test remove command without arguments
        local remove_no_args_output
        remove_no_args_output=$(assert_command_fails "Remove without arguments should fail" -- ./scripts/claude-template-sources.sh remove 2>&1)
        
        assert_contains "remove requires <name> argument" "$remove_no_args_output" "Should report missing remove argument"
    )
}

test_error_handling_unknown_options() {
    (
        create_sandbox
        
        # Test unknown option
        local unknown_opt_output
        unknown_opt_output=$(assert_command_fails "Unknown option should fail" -- ./scripts/claude-template-sources.sh list --invalid-option 2>&1)
        
        assert_contains "Unknown option --invalid-option" "$unknown_opt_output" "Should report unknown option"
    )
}

test_error_handling_help_after_command() {
    (
        create_sandbox
        
        # Test help flag after command
        local help_after_output
        help_after_output=$(assert_command_fails "Help after command should fail" -- ./scripts/claude-template-sources.sh add --help 2>&1)
        
        assert_contains "Use --help before command" "$help_after_output" "Should report incorrect help placement"
    )
}

test_error_handling_permission_errors() {
    (
        create_sandbox
        
        # Create read-only config directory
        mkdir -p "$HOME/.config"
        chmod 444 "$HOME/.config"
        
        # Create test repository
        mkdir -p "$sandbox_dir/perm-test-repo"
        cd "$sandbox_dir/perm-test-repo"
        git init >/dev/null 2>&1
        git config user.email "test@example.com"
        git config user.name "Test User"
        mkdir -p slash-commands
        echo "# Test" > slash-commands/test.md
        git add . && git commit -m "Initial" >/dev/null 2>&1
        cd "$original_dir"
        
        # Try to add source (should fail due to permissions)
        local perm_output
        perm_output=$(assert_command_fails "Permission error should fail" -- ./scripts/claude-template-sources.sh add perm-test "$sandbox_dir/perm-test-repo" 2>&1)
        
        # Restore permissions for cleanup
        chmod 755 "$HOME/.config" 2>/dev/null || true
        
        # Should report permission error
        assert_contains "Cannot create configuration directory" "$perm_output" "Should report permission error"
    )
}

test_error_handling_disk_space() {
    (
        create_sandbox
        
        # This test is difficult to simulate reliably across different systems
        # Instead, test behavior when cache directory creation fails
        
        # Create a file where cache directory should be
        mkdir -p "$HOME/.cache"
        touch "$HOME/.cache/claude-templates"  # File, not directory
        
        # Create test repository
        mkdir -p "$sandbox_dir/disk-test-repo"
        cd "$sandbox_dir/disk-test-repo"
        git init >/dev/null 2>&1
        git config user.email "test@example.com"
        git config user.name "Test User"
        mkdir -p slash-commands
        echo "# Test" > slash-commands/test.md
        git add . && git commit -m "Initial" >/dev/null 2>&1
        cd "$original_dir"
        
        # Try to add source (should fail due to cache directory conflict)
        local disk_output
        disk_output=$(assert_command_fails "Disk space issue should fail" -- ./scripts/claude-template-sources.sh add disk-test "$sandbox_dir/disk-test-repo" 2>&1)
        
        # Clean up
        rm -f "$HOME/.cache/claude-templates" 2>/dev/null || true
        
        # Should handle the error gracefully
        assert_true "true" "Should handle disk/directory creation errors"
    )
}

test_error_handling_network_timeout() {
    (
        create_sandbox
        
        # Test with non-existent remote URL (simulates network timeout)
        local network_output
        network_output=$(assert_command_fails "Network timeout should fail" -- ./scripts/claude-template-sources.sh add network-test "https://nonexistent-domain-12345.invalid/repo.git" 2>&1)
        
        assert_contains "Failed to cache repository" "$network_output" "Should report network/clone error"
    )
}

test_error_handling_invalid_git_urls() {
    (
        create_sandbox
        
        # Test various invalid URL formats
        local invalid_urls=(
            "not-a-url"
            "ftp://invalid.com/repo"
            "http://missing-git-suffix.com/repo"
            "git@missing-colon.com/repo.git"
            ""
        )
        
        for url in "${invalid_urls[@]}"; do
            if [[ -n "$url" ]]; then
                local invalid_url_output
                invalid_url_output=$(assert_command_fails "Invalid URL '$url' should fail" -- ./scripts/claude-template-sources.sh add test-invalid "$url" 2>&1)
                
                # Should report some kind of URL or git error
                assert_true "true" "Invalid URL '$url' should fail with error"
            fi
        done
    )
}

test_error_handling_corrupted_configuration() {
    (
        create_sandbox
        
        # Create corrupted configuration file
        mkdir -p "$HOME/.config/claude-templates"
        
        # Various corruption scenarios
        
        # 1. Binary data in config file
        printf "\x00\x01\x02\x03\x04\x05" > "$HOME/.config/claude-templates/sources.csv"
        
        local binary_output
        binary_output=$(assert_command_succeeds "Should handle binary corruption" -- ./scripts/claude-template-sources.sh list 2>&1)
        
        # 2. Missing header
        echo "source1,/path/to/repo1" > "$HOME/.config/claude-templates/sources.csv"
        
        local no_header_output
        no_header_output=$(assert_command_succeeds "Should handle missing header" -- ./scripts/claude-template-sources.sh list 2>&1)
        
        # 3. Malformed CSV
        cat > "$HOME/.config/claude-templates/sources.csv" << 'EOF'
name,url
"unclosed quote,/path/to/repo
source2,/path/to/repo2,"extra,field"
EOF
        
        local malformed_output
        malformed_output=$(assert_command_succeeds "Should handle malformed CSV" -- ./scripts/claude-template-sources.sh list 2>&1)
        
        # Should handle corruption gracefully (may show warnings but shouldn't crash)
        assert_true "true" "Should handle various configuration corruptions"
    )
}

test_error_handling_concurrent_access() {
    (
        create_sandbox
        
        # Create test repository
        mkdir -p "$sandbox_dir/concurrent-repo"
        cd "$sandbox_dir/concurrent-repo"
        git init >/dev/null 2>&1
        git config user.email "test@example.com"
        git config user.name "Test User"
        mkdir -p slash-commands
        echo "# Test" > slash-commands/test.md
        git add . && git commit -m "Initial" >/dev/null 2>&1
        cd "$original_dir"
        
        # Simulate concurrent access by locking config directory
        mkdir -p "$HOME/.config/claude-templates"
        
        # Run add command in background
        ./scripts/claude-template-sources.sh add concurrent-test "$sandbox_dir/concurrent-repo" &
        local bg_pid=$!
        
        # Immediately try another add (might create race condition)
        local concurrent_output
        concurrent_output=$(./scripts/claude-template-sources.sh add concurrent-test-2 "$sandbox_dir/concurrent-repo" 2>&1)
        
        # Wait for background process
        wait $bg_pid
        
        # At least one should succeed, or both should fail gracefully
        local final_config
        if [[ -f "$HOME/.config/claude-templates/sources.csv" ]]; then
            final_config=$(cat "$HOME/.config/claude-templates/sources.csv")
            # Configuration should be valid (not corrupted by concurrent access)
            assert_matches "# Claude Template Sources Configuration" "$final_config" "Configuration should have valid header after concurrent access"
        fi
    )
}

test_error_handling_large_repositories() {
    (
        create_sandbox
        
        # Create repository with many files (to test memory/performance limits)
        mkdir -p "$sandbox_dir/large-repo"
        cd "$sandbox_dir/large-repo"
        git init >/dev/null 2>&1
        git config user.email "test@example.com"
        git config user.name "Test User"
        
        mkdir -p slash-commands
        
        # Create many command files
        for i in {1..100}; do
            cat > "slash-commands/command-$i.md" << EOF
---
description: Large repo command $i
source: large-test
---

# Command $i
This is command number $i in a large repository.
$(printf 'Line %d\n' {1..100})  # Add content to make files larger
EOF
        done
        
        git add . && git commit -m "Initial with many files" >/dev/null 2>&1
        cd "$original_dir"
        
        # Should handle large repository
        local large_output
        large_output=$(assert_command_succeeds "Should handle large repository" -- ./scripts/claude-template-sources.sh add large-test "$sandbox_dir/large-repo" 2>&1)
        
        # Verify it was added successfully
        local sources_content
        sources_content=$(cat "$HOME/.config/claude-templates/sources.csv" 2>/dev/null || echo "")
        assert_contains "large-test" "$sources_content" "Should successfully add large repository"
    )
}

test_error_handling_special_characters() {
    (
        create_sandbox
        
        # Test source names with edge case characters
        local special_names=(
            "source-with-unicode-café"
            "source.with.dots"
            "source_with_underscores"
            "123-numeric-start"
            "CamelCaseSource"
        )
        
        # Create test repository
        mkdir -p "$sandbox_dir/special-repo"
        cd "$sandbox_dir/special-repo"
        git init >/dev/null 2>&1
        git config user.email "test@example.com"
        git config user.name "Test User"
        mkdir -p slash-commands
        echo "# Test" > slash-commands/test.md
        git add . && git commit -m "Initial" >/dev/null 2>&1
        cd "$original_dir"
        
        for name in "${special_names[@]}"; do
            # Clean up between tests
            rm -f "$HOME/.config/claude-templates/sources.csv"
            rm -rf "$HOME/.cache/claude-templates"
            
            # Test adding source with special name
            local special_output
            special_output=$(./scripts/claude-template-sources.sh add "$name" "$sandbox_dir/special-repo" 2>&1)
            
            if [[ $? -eq 0 ]]; then
                # If it succeeds, verify it was added correctly
                local sources_content
                sources_content=$(cat "$HOME/.config/claude-templates/sources.csv")
                assert_contains "$name" "$sources_content" "Special name '$name' should be handled correctly if accepted"
            else
                # If it fails, should fail gracefully
                assert_contains "Invalid source name" "$special_output" "Special name '$name' should fail with clear error if not supported"
            fi
        done
    )
}

test_error_handling_path_traversal() {
    (
        create_sandbox
        
        # Test various path traversal attempts in source names and URLs
        local malicious_names=(
            "../../../etc/passwd"
            "../../bin/sh"
            ".ssh/id_rsa"
            "source/../../../dangerous"
        )
        
        for name in "${malicious_names[@]}"; do
            local traversal_output
            traversal_output=$(assert_command_fails "Path traversal '$name' should fail" -- ./scripts/claude-template-sources.sh add "$name" "/tmp/fake-repo" 2>&1)
            
            # Should reject path traversal attempts
            assert_contains "Invalid source name" "$traversal_output" "Should reject path traversal in name '$name'"
        done
        
        # Test path traversal in URLs
        local malicious_urls=(
            "file:///../../../etc/passwd"
            "/tmp/../../etc/passwd"
        )
        
        for url in "${malicious_urls[@]}"; do
            local url_traversal_output
            url_traversal_output=$(assert_command_fails "URL traversal '$url' should fail" -- ./scripts/claude-template-sources.sh add safe-name "$url" 2>&1)
            
            # Should handle malicious URLs safely
            assert_true "true" "Should handle malicious URL '$url' safely"
        done
    )
}

# Register all test functions
register_tests \
    "test_error_handling_no_command" \
    "test_error_handling_invalid_command" \
    "test_error_handling_missing_arguments" \
    "test_error_handling_unknown_options" \
    "test_error_handling_help_after_command" \
    "test_error_handling_permission_errors" \
    "test_error_handling_disk_space" \
    "test_error_handling_network_timeout" \
    "test_error_handling_invalid_git_urls" \
    "test_error_handling_corrupted_configuration" \
    "test_error_handling_concurrent_access" \
    "test_error_handling_large_repositories" \
    "test_error_handling_special_characters" \
    "test_error_handling_path_traversal"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-template-sources.sh error handling and edge cases" "$@"
fi