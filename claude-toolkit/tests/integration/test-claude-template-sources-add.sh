#!/bin/bash
# test-claude-template-sources-add.sh - Tests claude-template-sources.sh add functionality
# 
# Purpose: Test scripts/claude-template-sources.sh add command functionality
# Dependencies: None (creates own test repositories)
# Approach: Create test git repositories and verify source addition functionality

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

test_add_source_basic() {
    (
        create_sandbox
        
        # Create test template repository
        mkdir -p "$sandbox_dir/test-repo"
        cd "$sandbox_dir/test-repo"
        git init >/dev/null 2>&1
        git config user.email "test@example.com"
        git config user.name "Test User"
        
        # Create sample slash commands
        mkdir -p slash-commands
        cat > "slash-commands/test-command.md" << 'EOF'
---
description: Test command from repository
source: test-source
---

# Test Command
Test command content
EOF
        
        git add .
        git commit -m "Initial commit" >/dev/null 2>&1
        
        cd "$original_dir"
        
        # Test adding the source
        assert_command_succeeds "Adding source should succeed" -- ./scripts/claude-template-sources.sh add test-source "$sandbox_dir/test-repo" >/dev/null 2>&1
        
        # Verify source was added to configuration
        assert_file_exists "$HOME/.config/claude-templates/sources.csv" "Sources configuration file should be created"
        
        local sources_content
        sources_content=$(cat "$HOME/.config/claude-templates/sources.csv")
        assert_contains "test-source" "$sources_content" "Configuration should contain source name"
        assert_contains "$sandbox_dir/test-repo" "$sources_content" "Configuration should contain repository path"
    )
}

test_add_source_duplicate_name() {
    (
        create_sandbox
        
        # Create first test repository
        mkdir -p "$sandbox_dir/repo1"
        cd "$sandbox_dir/repo1"
        git init >/dev/null 2>&1
        git config user.email "test@example.com"
        git config user.name "Test User"
        mkdir -p slash-commands
        echo "# Repo 1" > slash-commands/test1.md
        git add . && git commit -m "Initial" >/dev/null 2>&1
        
        # Create second test repository  
        mkdir -p "$sandbox_dir/repo2"
        cd "$sandbox_dir/repo2"
        git init >/dev/null 2>&1
        git config user.email "test@example.com"
        git config user.name "Test User"
        mkdir -p slash-commands
        echo "# Repo 2" > slash-commands/test2.md
        git add . && git commit -m "Initial" >/dev/null 2>&1
        
        cd "$original_dir"
        
        # Add first source
        assert_command_succeeds "First source should be added" -- ./scripts/claude-template-sources.sh add duplicate-test "$sandbox_dir/repo1" >/dev/null 2>&1
        
        # Try to add second source with same name - should fail
        local duplicate_output
        duplicate_output=$(assert_command_fails "Duplicate source name should fail" -- ./scripts/claude-template-sources.sh add duplicate-test "$sandbox_dir/repo2" 2>&1)
        
        assert_contains "already exists" "$duplicate_output" "Should report duplicate source error"
        
        # Verify original source remains unchanged
        local sources_content
        sources_content=$(cat "$HOME/.config/claude-templates/sources.csv")
        assert_contains "$sandbox_dir/repo1" "$sources_content" "Should still contain original repository URL"
        assert_not_contains "$sandbox_dir/repo2" "$sources_content" "Should not contain second repository URL"
    )
}

test_add_source_duplicate_url() {
    (
        create_sandbox
        
        # Create test repository
        mkdir -p "$sandbox_dir/test-repo"
        cd "$sandbox_dir/test-repo"
        git init >/dev/null 2>&1
        git config user.email "test@example.com"
        git config user.name "Test User"
        mkdir -p slash-commands
        echo "# Test" > slash-commands/test.md
        git add . && git commit -m "Initial" >/dev/null 2>&1
        
        cd "$original_dir"
        
        # Add first source
        assert_command_succeeds "First source should be added" -- ./scripts/claude-template-sources.sh add source1 "$sandbox_dir/test-repo" >/dev/null 2>&1
        
        # Try to add second source with same URL but different name - should fail
        local duplicate_url_output
        duplicate_url_output=$(assert_command_fails "Duplicate URL should fail" -- ./scripts/claude-template-sources.sh add source2 "$sandbox_dir/test-repo" 2>&1)
        
        assert_contains "already configured" "$duplicate_url_output" "Should report duplicate URL error"
        
        # Verify only first source exists
        local sources_content
        sources_content=$(cat "$HOME/.config/claude-templates/sources.csv")
        assert_contains "source1" "$sources_content" "Should contain first source name"
        assert_not_contains "source2" "$sources_content" "Should not contain second source name"
    )
}

test_add_source_name_validation() {
    (
        create_sandbox
        
        # Create test repository
        mkdir -p "$sandbox_dir/validation-repo"
        cd "$sandbox_dir/validation-repo"
        git init >/dev/null 2>&1
        git config user.email "test@example.com"
        git config user.name "Test User"
        mkdir -p slash-commands
        echo "# Test" > slash-commands/test.md
        git add . && git commit -m "Initial" >/dev/null 2>&1
        
        cd "$original_dir"
        
        # Test invalid source names
        local invalid_names=("" "source with spaces" "source/slash" "source\\backslash" "source:colon")
        
        for name in "${invalid_names[@]}"; do
            if [[ -n "$name" ]]; then
                local invalid_output
                invalid_output=$(assert_command_fails "Invalid name '$name' should fail" -- ./scripts/claude-template-sources.sh add "$name" "$sandbox_dir/validation-repo" 2>&1)
                assert_contains "Invalid source name" "$invalid_output" "Should report invalid name error for '$name'"
            fi
        done
        
        # Test valid source names
        local valid_names=("valid-name" "valid_name" "ValidName123" "team-alpha" "my-custom-source")
        
        for name in "${valid_names[@]}"; do
            # Clean up between tests
            rm -f "$HOME/.config/claude-templates/sources.csv"
            rm -rf "$HOME/.cache/claude-templates"
            
            assert_command_succeeds "Valid name '$name' should succeed" -- ./scripts/claude-template-sources.sh add "$name" "$sandbox_dir/validation-repo" >/dev/null 2>&1
            
            local sources_content
            sources_content=$(cat "$HOME/.config/claude-templates/sources.csv")
            assert_contains "$name" "$sources_content" "Should accept valid name '$name'"
        done
    )
}

test_add_source_git_url_formats() {
    (
        create_sandbox
        
        # Create test repository
        mkdir -p "$sandbox_dir/url-test-repo"
        cd "$sandbox_dir/url-test-repo"
        git init >/dev/null 2>&1
        git config user.email "test@example.com"
        git config user.name "Test User"
        mkdir -p slash-commands
        echo "# Test" > slash-commands/test.md
        git add . && git commit -m "Initial" >/dev/null 2>&1
        
        cd "$original_dir"
        
        # Test different URL formats (all pointing to same local repo)
        local url_formats=(
            "$sandbox_dir/url-test-repo"                    # Absolute path
            "file://$sandbox_dir/url-test-repo"             # File protocol
        )
        
        for i in "${!url_formats[@]}"; do
            local url="${url_formats[$i]}"
            local source_name="url-format-$i"
            
            # Clean up between tests
            rm -f "$HOME/.config/claude-templates/sources.csv"
            rm -rf "$HOME/.cache/claude-templates"
            
            assert_command_succeeds "URL format '$url' should be accepted" -- ./scripts/claude-template-sources.sh add "$source_name" "$url" >/dev/null 2>&1
            
            local sources_content
            sources_content=$(cat "$HOME/.config/claude-templates/sources.csv")
            assert_contains "$source_name" "$sources_content" "Should accept URL format '$url'"
        done
    )
}

test_add_source_configuration_file_format() {
    (
        create_sandbox
        
        # Create test repositories
        mkdir -p "$sandbox_dir/repo1" "$sandbox_dir/repo2"
        
        for i in 1 2; do
            cd "$sandbox_dir/repo$i"
            git init >/dev/null 2>&1
            git config user.email "test@example.com"
            git config user.name "Test User"
            mkdir -p slash-commands
            echo "# Repo $i" > "slash-commands/test$i.md"
            git add . && git commit -m "Initial" >/dev/null 2>&1
        done
        
        cd "$original_dir"
        
        # Add multiple sources
        assert_command_succeeds "First source should be added" -- ./scripts/claude-template-sources.sh add source1 "$sandbox_dir/repo1" >/dev/null 2>&1
        assert_command_succeeds "Second source should be added" -- ./scripts/claude-template-sources.sh add source2 "$sandbox_dir/repo2" >/dev/null 2>&1
        
        # Verify CSV format
        local sources_content
        sources_content=$(cat "$HOME/.config/claude-templates/sources.csv")
        
        # Check configuration format (tab-separated)
        assert_contains "# Claude Template Sources Configuration" "$(head -n1 "$HOME/.config/claude-templates/sources.csv")" "Should have configuration header"
        
        # Check tab-separated format (name<TAB>url)
        local source1_line=$(grep "source1" "$HOME/.config/claude-templates/sources.csv")
        local source2_line=$(grep "source2" "$HOME/.config/claude-templates/sources.csv")
        
        assert_contains "source1	$sandbox_dir/repo1" "$source1_line" "Should have correct tab-separated format for source1"
        assert_contains "source2	$sandbox_dir/repo2" "$source2_line" "Should have correct tab-separated format for source2"
        
        # Verify line count (3 comment lines + claude-toolkit + 2 sources = 6 lines)
        local line_count=$(wc -l < "$HOME/.config/claude-templates/sources.csv" | tr -d ' ')
        assert_equals "6" "$line_count" "Should have exactly 6 lines (header comments + claude-toolkit + 2 sources)"
    )
}

# Register all test functions
register_tests \
    "test_add_source_basic" \
    "test_add_source_duplicate_name" \
    "test_add_source_duplicate_url" \
    "test_add_source_name_validation" \
    "test_add_source_git_url_formats" \
    "test_add_source_configuration_file_format"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-template-sources.sh add functionality" "$@"
fi
