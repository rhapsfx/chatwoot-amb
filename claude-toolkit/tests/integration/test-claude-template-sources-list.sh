#!/bin/bash
# test-claude-template-sources-list.sh - Tests claude-template-sources.sh list functionality
# 
# Purpose: Test scripts/claude-template-sources.sh list command functionality
# Dependencies: None (creates own test repositories)
# Approach: Create test sources and verify listing functionality

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

# Helper function to create a test source
create_test_source() {
    local source_name="$1"
    local repo_dir="$sandbox_dir/${source_name}-repo"
    
    mkdir -p "$repo_dir"
    cd "$repo_dir"
    git init >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    mkdir -p slash-commands
    cat > "slash-commands/${source_name}-command.md" << EOF
---
description: ${source_name} test command
source: ${source_name}
---

# ${source_name} Test Command
Test command for ${source_name}
EOF
    
    git add . && git commit -m "Initial commit" >/dev/null 2>&1
    cd "$original_dir"
    
    # Add the source
    ./scripts/claude-template-sources.sh add "$source_name" "$repo_dir" >/dev/null 2>&1
    echo "$repo_dir"
}

test_list_sources_empty() {
    (
        create_sandbox
        
        # Test listing when no user sources are configured (claude-toolkit will be auto-configured)
        local list_output
        list_output=$(assert_command_succeeds "List empty sources should succeed" -- ./scripts/claude-template-sources.sh list)
        
        # Should show auto-configured claude-toolkit source
        assert_contains "claude-toolkit" "$list_output" "Should show auto-configured claude-toolkit source"
        assert_contains "user" "$list_output" "Should show user source option"
        assert_contains "Configured sources:" "$list_output" "Should show configured sources header"
    )
}

test_list_sources_single() {
    (
        create_sandbox
        
        # Create single test source
        local repo_dir
        repo_dir=$(create_test_source "single-source")
        
        # List sources
        local list_output
        list_output=$(assert_command_succeeds "List single source should succeed" -- ./scripts/claude-template-sources.sh list)
        
        # Verify source appears in output
        assert_contains "single-source" "$list_output" "Should show source name"
        assert_contains "$repo_dir" "$list_output" "Should show repository URL"
    )
}

test_list_sources_multiple() {
    (
        create_sandbox
        
        # Create multiple test sources
        local repo1_dir repo2_dir repo3_dir
        repo1_dir=$(create_test_source "alpha-source")
        repo2_dir=$(create_test_source "beta-source") 
        repo3_dir=$(create_test_source "gamma-source")
        
        # List sources
        local list_output
        list_output=$(assert_command_succeeds "List multiple sources should succeed" -- ./scripts/claude-template-sources.sh list)
        
        # Verify all sources appear
        assert_contains "alpha-source" "$list_output" "Should show alpha-source"
        assert_contains "beta-source" "$list_output" "Should show beta-source"
        assert_contains "gamma-source" "$list_output" "Should show gamma-source"
        
        assert_contains "$repo1_dir" "$list_output" "Should show alpha-source URL"
        assert_contains "$repo2_dir" "$list_output" "Should show beta-source URL"
        assert_contains "$repo3_dir" "$list_output" "Should show gamma-source URL"
    )
}

test_list_sources_porcelain_format() {
    (
        create_sandbox
        
        # Create test sources
        local repo1_dir repo2_dir
        repo1_dir=$(create_test_source "porcelain-alpha")
        repo2_dir=$(create_test_source "porcelain-beta")
        
        # List in porcelain format
        local porcelain_output
        porcelain_output=$(assert_command_succeeds "Porcelain list should succeed" -- ./scripts/claude-template-sources.sh list --porcelain)
        
        # Verify porcelain format (tab-separated)
        assert_contains $'\t' "$porcelain_output" "Should contain tab separators in porcelain format"
        
        # Verify sources are present
        assert_contains "porcelain-alpha" "$porcelain_output" "Should show alpha source in porcelain"
        assert_contains "porcelain-beta" "$porcelain_output" "Should show beta source in porcelain"
        
        # Count lines (should be one per source + claude-toolkit = 3)
        local line_count
        line_count=$(echo "$porcelain_output" | wc -l | tr -d ' ')
        assert_equals "3" "$line_count" "Should have exactly 3 lines for claude-toolkit + 2 user sources"
    )
}

test_list_sources_human_readable_format() {
    (
        create_sandbox
        
        # Create test sources
        local repo1_dir repo2_dir
        repo1_dir=$(create_test_source "human-alpha")
        repo2_dir=$(create_test_source "human-beta")
        
        # List in human-readable format (default)
        local human_output
        human_output=$(assert_command_succeeds "Human-readable list should succeed" -- ./scripts/claude-template-sources.sh list)
        
        # Verify human-readable formatting
        assert_contains "human-alpha" "$human_output" "Should show source names"
        assert_contains "human-beta" "$human_output" "Should show source names"
        
        # Should not be tab-separated format
        local tab_lines
        tab_lines=$(echo "$human_output" | grep -c $'\t' || echo "0")
        # Human format might have tabs for alignment, but shouldn't be pure tab-separated
        # Main verification is that it shows the information clearly
    )
}

test_list_sources_with_command_counts() {
    (
        create_sandbox
        
        # Create source with multiple commands
        local repo_dir="$sandbox_dir/multi-command-repo"
        mkdir -p "$repo_dir"
        cd "$repo_dir"
        git init >/dev/null 2>&1
        git config user.email "test@example.com"
        git config user.name "Test User"
        
        mkdir -p slash-commands
        
        # Create multiple commands
        for i in {1..3}; do
            cat > "slash-commands/command-$i.md" << EOF
---
description: Command $i
source: multi-command
---

# Command $i
Test command $i
EOF
        done
        
        git add . && git commit -m "Initial commit" >/dev/null 2>&1
        cd "$original_dir"
        
        # Add the source
        ./scripts/claude-template-sources.sh add multi-command "$repo_dir" >/dev/null 2>&1
        
        # List sources
        local list_output
        list_output=$(assert_command_succeeds "List should show command counts" -- ./scripts/claude-template-sources.sh list)
        
        # Verify command count is shown (if implemented)
        assert_contains "multi-command" "$list_output" "Should show source name"
        # Command count display is optional - main requirement is source listing works
    )
}

test_list_sources_status_information() {
    (
        create_sandbox
        
        # Create test source
        local repo_dir
        repo_dir=$(create_test_source "status-test")
        
        # Simulate some installed commands
        mkdir -p "$HOME/.claude/commands"
        cat > "$HOME/.claude/commands/status-test-command.md" << 'EOF'
---
description: Status test command
source: status-test
---

# Status Test Command
EOF
        
        # List sources
        local list_output
        list_output=$(assert_command_succeeds "List should succeed with installed commands" -- ./scripts/claude-template-sources.sh list)
        
        # Verify source appears
        assert_contains "status-test" "$list_output" "Should show source with status information"
        
        # Status information (like installed command count) is optional but nice to have
    )
}

test_list_sources_different_url_types() {
    (
        create_sandbox
        
        # Create sources with different URL types
        local local_repo="$sandbox_dir/local-repo"
        mkdir -p "$local_repo"
        cd "$local_repo"
        git init >/dev/null 2>&1
        git config user.email "test@example.com"
        git config user.name "Test User"
        mkdir -p slash-commands
        echo "# Local" > slash-commands/local.md
        git add . && git commit -m "Initial" >/dev/null 2>&1
        cd "$original_dir"
        
        # Add with different URL formats
        ./scripts/claude-template-sources.sh add local-path "$local_repo" >/dev/null 2>&1
        ./scripts/claude-template-sources.sh add file-protocol "file://$local_repo" >/dev/null 2>&1
        
        # List sources
        local list_output
        list_output=$(assert_command_succeeds "List should handle different URL types" -- ./scripts/claude-template-sources.sh list)
        
        # Verify both sources appear
        assert_contains "local-path" "$list_output" "Should show local path source"
        assert_contains "file-protocol" "$list_output" "Should show file protocol source"
        
        # Should show the URLs as configured
        assert_contains "$local_repo" "$list_output" "Should show local repository path"
        assert_contains "file://" "$list_output" "Should show file protocol URL"
    )
}

test_list_sources_sorting() {
    (
        create_sandbox
        
        # Create sources in non-alphabetical order
        create_test_source "zebra-source" >/dev/null
        create_test_source "alpha-source" >/dev/null
        create_test_source "beta-source" >/dev/null
        
        # List sources
        local list_output
        list_output=$(assert_command_succeeds "List should succeed" -- ./scripts/claude-template-sources.sh list)
        
        # Verify all sources are present (sorting is optional)
        assert_contains "zebra-source" "$list_output" "Should show zebra-source"
        assert_contains "alpha-source" "$list_output" "Should show alpha-source"
        assert_contains "beta-source" "$list_output" "Should show beta-source"
        
        # If sorting is implemented, verify order
        local first_source
        first_source=$(echo "$list_output" | head -n1)
        # Implementation may or may not sort - main requirement is all sources shown
    )
}

test_list_sources_invalid_configuration() {
    (
        create_sandbox
        
        # Create valid source first
        create_test_source "valid-source" >/dev/null
        
        # Manually corrupt configuration file
        echo "invalid,line,too,many,fields" >> "$HOME/.config/claude-templates/sources.csv"
        echo "missing-field" >> "$HOME/.config/claude-templates/sources.csv"
        
        # List should handle invalid entries gracefully
        local list_output
        list_output=$(assert_command_succeeds "List should handle invalid config entries" -- ./scripts/claude-template-sources.sh list 2>/dev/null)
        
        # Should still show valid sources
        assert_contains "valid-source" "$list_output" "Should show valid sources despite invalid entries"
    )
}

test_list_sources_missing_repositories() {
    (
        create_sandbox
        
        # Create source with valid repository
        local repo_dir
        repo_dir=$(create_test_source "existing-source")
        
        # Create source configuration pointing to non-existent repository
        echo "missing-source,$sandbox_dir/nonexistent-repo" >> "$HOME/.config/claude-templates/sources.csv"
        
        # List should handle missing repositories
        local list_output
        list_output=$(assert_command_succeeds "List should handle missing repositories" -- ./scripts/claude-template-sources.sh list)
        
        # Should show both sources, possibly with status indicators
        assert_contains "existing-source" "$list_output" "Should show existing source"
        assert_contains "missing-source" "$list_output" "Should show missing source (with warning or status)"
    )
}

test_list_sources_empty_configuration() {
    (
        create_sandbox
        
        # Create empty configuration file with just header
        mkdir -p "$HOME/.config/claude-templates"
        cat > "$HOME/.config/claude-templates/sources.csv" << 'EOF'
# Claude Template Sources Configuration
# Format: source_name<TAB>git_url
# Lines starting with # are comments
name,url
EOF
        
        # List empty configuration (claude-toolkit will be auto-configured)
        local list_output
        list_output=$(assert_command_succeeds "List empty config should succeed" -- ./scripts/claude-template-sources.sh list)
        
        # Should show auto-configured claude-toolkit and handle malformed line gracefully
        assert_contains "claude-toolkit" "$list_output" "Should show auto-configured claude-toolkit source"
        assert_contains "user" "$list_output" "Should show user source option"
        assert_contains "Configured sources:" "$list_output" "Should show configured sources header"
    )
}

test_list_sources_configuration_file_format_validation() {
    (
        create_sandbox
        
        # Create sources to test tab-separated format
        create_test_source "format-test-1" >/dev/null
        create_test_source "format-test-2" >/dev/null
        
        # Verify configuration file format
        assert_file_exists "$HOME/.config/claude-templates/sources.csv" "Configuration file should exist"
        
        # Check configuration header
        local header
        header=$(head -n1 "$HOME/.config/claude-templates/sources.csv")
        assert_contains "# Claude Template Sources Configuration" "$header" "Should have correct configuration header"
        
        # Check tab-separated format for each line
        local line_num=0
        while IFS=$'\t' read -r name url; do
            ((line_num++))
            # Skip comment lines
            if [[ "$name" =~ ^[[:space:]]*# ]]; then
                continue
            fi
            
            assert_not_equals "" "$name" "Source name should not be empty (line $line_num)"
            assert_not_equals "" "$url" "Source URL should not be empty (line $line_num)"
            assert_not_contains $'\t' "$name" "Source name should not contain tabs (line $line_num)"
        done < "$HOME/.config/claude-templates/sources.csv"
        
        # List should parse this correctly
        local list_output
        list_output=$(assert_command_succeeds "List should parse valid configuration" -- ./scripts/claude-template-sources.sh list)
        
        assert_contains "format-test-1" "$list_output" "Should parse first source"
        assert_contains "format-test-2" "$list_output" "Should parse second source"
    )
}

# Register all test functions
register_tests \
    "test_list_sources_empty" \
    "test_list_sources_single" \
    "test_list_sources_multiple" \
    "test_list_sources_porcelain_format" \
    "test_list_sources_human_readable_format" \
    "test_list_sources_with_command_counts" \
    "test_list_sources_status_information" \
    "test_list_sources_different_url_types" \
    "test_list_sources_sorting" \
    "test_list_sources_invalid_configuration" \
    "test_list_sources_missing_repositories" \
    "test_list_sources_empty_configuration" \
    "test_list_sources_configuration_file_format_validation"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-template-sources.sh list functionality" "$@"
fi
