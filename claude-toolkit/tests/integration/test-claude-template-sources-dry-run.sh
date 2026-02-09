#!/bin/bash
# test-claude-template-sources-dry-run.sh - Tests claude-template-sources.sh dry-run functionality
# 
# Purpose: Test scripts/claude-template-sources.sh dry-run mode for all commands
# Dependencies: None (creates own test repositories)
# Approach: Test that dry-run mode shows what would be done without making changes

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

# Helper function to create a test repository
create_test_repository() {
    local repo_name="$1"
    local repo_dir="$sandbox_dir/${repo_name}-repo"
    
    mkdir -p "$repo_dir"
    cd "$repo_dir"
    git init >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    mkdir -p slash-commands
    cat > "slash-commands/${repo_name}-command.md" << EOF
---
description: ${repo_name} test command
source: ${repo_name}
---

# ${repo_name} Command
Test command for ${repo_name}
EOF
    
    git add . && git commit -m "Initial commit" >/dev/null 2>&1
    cd "$original_dir"
    
    echo "$repo_dir"
}

test_dry_run_add_new_source() {
    (
        create_sandbox
        
        local initial_checksum
        initial_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        
        # Create test repository
        local repo_dir
        repo_dir=$(create_test_repository "dry-run-add")
        
        # Test dry-run add
        local dry_run_output
        dry_run_output=$(assert_command_succeeds "Dry-run add should succeed" -- ./scripts/claude-template-sources.sh add dry-run-add "$repo_dir" --dry-run 2>&1)
        
        # Verify dry-run function call
        assert_contains "dryrun:add_template_source" "$dry_run_output" "Should print dryrun:add_template_source function name"
        
        # Verify no actual changes were made
        local final_checksum
        final_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        assert_equals "$initial_checksum" "$final_checksum" "Dry-run add should make no filesystem changes"
    )
}

test_dry_run_add_duplicate_source() {
    (
        create_sandbox
        
        local initial_checksum
        initial_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        
        # Create and add a real source
        local repo_dir
        repo_dir=$(create_test_repository "existing-source")
        ./scripts/claude-template-sources.sh add existing-source "$repo_dir" >/dev/null 2>&1
        
        # Verify source exists
        assert_file_exists "$HOME/.config/claude-templates/sources.csv" "Real source should be configured"
        
        # Create another repository
        local repo2_dir
        repo2_dir=$(create_test_repository "duplicate-attempt")
        
        # Test dry-run add with duplicate name
        local dry_run_output
        dry_run_output=$(assert_command_succeeds "Dry-run duplicate should succeed" -- ./scripts/claude-template-sources.sh add existing-source "$repo2_dir" --dry-run 2>&1)
        
        # Should show dry-run function call (no validation performed)
        assert_contains "dryrun:add_template_source" "$dry_run_output" "Should print dryrun:add_template_source function name"
        
        # Verify no filesystem changes
        local final_checksum
        final_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        assert_equals "$initial_checksum" "$final_checksum" "Dry-run should make no filesystem changes"
        
        # Verify original configuration unchanged
        local sources_content
        sources_content=$(cat "$HOME/.config/claude-templates/sources.csv")
        assert_contains "$repo_dir" "$sources_content" "Original source should remain unchanged"
        assert_not_contains "$repo2_dir" "$sources_content" "Duplicate source should not be added"
    )
}

test_dry_run_add_validation_errors() {
    (
        create_sandbox
        
        local initial_checksum
        initial_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        
        # Test dry-run with invalid repository
        mkdir -p "$sandbox_dir/not-git-repo"
        echo "not a git repo" > "$sandbox_dir/not-git-repo/README.md"
        
        local invalid_repo_output
        invalid_repo_output=$(assert_command_succeeds "Dry-run invalid repo should succeed" -- ./scripts/claude-template-sources.sh add invalid-repo "$sandbox_dir/not-git-repo" --dry-run 2>&1)
        
        assert_contains "dryrun:add_template_source" "$invalid_repo_output" "Should print dryrun:add_template_source function name"
        
        # Test dry-run with missing slash-commands
        local empty_repo_dir="$sandbox_dir/empty-repo"
        mkdir -p "$empty_repo_dir"
        cd "$empty_repo_dir"
        git init >/dev/null 2>&1
        git config user.email "test@example.com"
        git config user.name "Test User"
        echo "# README" > README.md
        git add . && git commit -m "Initial" >/dev/null 2>&1
        cd "$original_dir"
        
        local empty_repo_output
        empty_repo_output=$(assert_command_succeeds "Dry-run empty repo should succeed" -- ./scripts/claude-template-sources.sh add empty-repo "$empty_repo_dir" --dry-run 2>&1)
        
        assert_contains "dryrun:add_template_source" "$empty_repo_output" "Should print dryrun:add_template_source function name"
        
        # Verify no filesystem changes
        local final_checksum
        final_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        assert_equals "$initial_checksum" "$final_checksum" "Dry-run should make no filesystem changes"
    )
}

test_dry_run_remove_existing_source() {
    (
        create_sandbox
        
        # Create and add a real source
        local repo_dir
        repo_dir=$(create_test_repository "to-remove")
        ./scripts/claude-template-sources.sh add to-remove "$repo_dir" >/dev/null 2>&1
        
        # Verify source exists
        local sources_before
        sources_before=$(cat "$HOME/.config/claude-templates/sources.csv")
        assert_contains "to-remove" "$sources_before" "Source should exist before dry-run remove"
        
        local initial_checksum
        initial_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        
        # Test dry-run remove
        local dry_run_output
        dry_run_output=$(assert_command_succeeds "Dry-run remove should succeed" -- ./scripts/claude-template-sources.sh remove to-remove --dry-run 2>&1)
        
        # Verify dry-run function call
        assert_contains "dryrun:remove_template_source" "$dry_run_output" "Should print dryrun:remove_template_source function name"
        
        # Verify no actual changes were made
        local sources_after
        sources_after=$(cat "$HOME/.config/claude-templates/sources.csv")
        assert_equals "$sources_before" "$sources_after" "Configuration should be unchanged in dry-run remove"
        
        local final_checksum
        final_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        assert_equals "$initial_checksum" "$final_checksum" "Dry-run should make no filesystem changes"
    )
}

test_dry_run_remove_nonexistent_source() {
    (
        create_sandbox
        
        local initial_checksum
        initial_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        
        # Test dry-run remove of non-existent source
        local dry_run_output
        dry_run_output=$(assert_command_succeeds "Dry-run remove nonexistent should succeed" -- ./scripts/claude-template-sources.sh remove nonexistent-source --dry-run 2>&1)
        
        # Should print function name (no validation performed in dry-run)
        assert_contains "dryrun:remove_template_source" "$dry_run_output" "Should print dryrun:remove_template_source function name"
        
        # Verify no filesystem changes
        local final_checksum
        final_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        assert_equals "$initial_checksum" "$final_checksum" "Dry-run should make no filesystem changes"
    )
}

test_dry_run_remove_with_multiple_sources() {
    (
        create_sandbox
        
        # Create multiple sources
        local repo1_dir repo2_dir repo3_dir
        repo1_dir=$(create_test_repository "source1")
        repo2_dir=$(create_test_repository "source2")
        repo3_dir=$(create_test_repository "source3")
        
        ./scripts/claude-template-sources.sh add source1 "$repo1_dir" >/dev/null 2>&1
        ./scripts/claude-template-sources.sh add source2 "$repo2_dir" >/dev/null 2>&1
        ./scripts/claude-template-sources.sh add source3 "$repo3_dir" >/dev/null 2>&1
        
        # Verify all sources exist
        local sources_before
        sources_before=$(cat "$HOME/.config/claude-templates/sources.csv")
        assert_contains "source1" "$sources_before" "Source1 should exist"
        assert_contains "source2" "$sources_before" "Source2 should exist"
        assert_contains "source3" "$sources_before" "Source3 should exist"
        
        local initial_checksum
        initial_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        
        # Test dry-run remove of middle source
        local dry_run_output
        dry_run_output=$(assert_command_succeeds "Dry-run remove middle source should succeed" -- ./scripts/claude-template-sources.sh remove source2 --dry-run 2>&1)
        
        assert_contains "dryrun:remove_template_source" "$dry_run_output" "Should print dryrun:remove_template_source function name"
        
        # Verify all sources still exist
        local sources_after
        sources_after=$(cat "$HOME/.config/claude-templates/sources.csv")
        assert_equals "$sources_before" "$sources_after" "All sources should remain in dry-run"
        
        local final_checksum
        final_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        assert_equals "$initial_checksum" "$final_checksum" "Dry-run should make no filesystem changes"
    )
}

test_dry_run_list_sources() {
    (
        create_sandbox
        
        # Create test sources
        local repo1_dir repo2_dir
        repo1_dir=$(create_test_repository "list-source1")
        repo2_dir=$(create_test_repository "list-source2")
        
        ./scripts/claude-template-sources.sh add list-source1 "$repo1_dir" >/dev/null 2>&1
        ./scripts/claude-template-sources.sh add list-source2 "$repo2_dir" >/dev/null 2>&1
        
        local initial_checksum
        initial_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        
        # Test dry-run list
        local dry_run_output
        dry_run_output=$(assert_command_succeeds "Dry-run list should succeed" -- ./scripts/claude-template-sources.sh list --dry-run 2>&1)
        
        # List is a read-only operation, so dry-run should call log_function and return
        assert_contains "dryrun:list_template_sources" "$dry_run_output" "Should print dryrun:list_template_sources function name"
        
        local final_checksum
        final_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        assert_equals "$initial_checksum" "$final_checksum" "Dry-run should make no filesystem changes"
    )
}

test_dry_run_list_empty() {
    (
        create_sandbox
        
        local initial_checksum
        initial_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        
        # Test dry-run list with no sources
        local dry_run_output
        dry_run_output=$(assert_command_succeeds "Dry-run list empty should succeed" -- ./scripts/claude-template-sources.sh list --dry-run 2>&1)
        
        # Should call log_function and return without doing anything
        assert_contains "dryrun:list_template_sources" "$dry_run_output" "Should print dryrun:list_template_sources function name"
        
        local final_checksum
        final_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        assert_equals "$initial_checksum" "$final_checksum" "Dry-run should make no filesystem changes"
    )
}

test_dry_run_complex_repository_validation() {
    (
        create_sandbox
        
        # Create repository with complex structure
        local complex_repo_dir="$sandbox_dir/complex-repo"
        mkdir -p "$complex_repo_dir"
        cd "$complex_repo_dir"
        git init >/dev/null 2>&1
        git config user.email "test@example.com"
        git config user.name "Test User"
        
        # Create multiple directories and files
        mkdir -p slash-commands/subdirectory
        mkdir -p docs templates
        
        # Create valid slash commands
        cat > "slash-commands/valid-command1.md" << 'EOF'
---
description: Valid command 1
source: complex-source
---

# Valid Command 1
EOF
        
        cat > "slash-commands/valid-command2.md" << 'EOF'
---
description: Valid command 2
source: complex-source
---

# Valid Command 2
EOF
        
        # Create some non-command files
        echo "# README" > README.md
        echo "# Docs" > docs/documentation.md
        echo "template" > templates/template.txt
        
        git add . && git commit -m "Complex repo" >/dev/null 2>&1
        cd "$original_dir"
        
        local initial_checksum
        initial_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        
        # Test dry-run add with complex repository
        local dry_run_output
        dry_run_output=$(assert_command_succeeds "Dry-run complex repo should succeed" -- ./scripts/claude-template-sources.sh add complex-source "$complex_repo_dir" --dry-run 2>&1)
        
        assert_contains "dryrun:add_template_source" "$dry_run_output" "Should print dryrun:add_template_source function name"
        
        # Verify no changes made
        local final_checksum
        final_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        assert_equals "$initial_checksum" "$final_checksum" "Dry-run should make no filesystem changes"
    )
}

test_dry_run_with_existing_cache() {
    (
        create_sandbox
        
        # Create and add a source normally first
        local repo_dir
        repo_dir=$(create_test_repository "cached-source")
        ./scripts/claude-template-sources.sh add cached-source "$repo_dir" >/dev/null 2>&1
        
        # Verify cache was created
        assert_directory_exists "$HOME/.cache/claude-templates" "Cache should exist from real add"
        
        # Create another repository
        local repo2_dir
        repo2_dir=$(create_test_repository "dry-run-with-cache")
        
        local initial_checksum
        initial_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        
        # Test dry-run add with existing cache
        local dry_run_output
        dry_run_output=$(assert_command_succeeds "Dry-run with existing cache should succeed" -- ./scripts/claude-template-sources.sh add dry-run-with-cache "$repo2_dir" --dry-run 2>&1)
        
        assert_contains "dryrun:add_template_source" "$dry_run_output" "Should print dryrun:add_template_source function name"
        
        # Verify cache wasn't modified
        local cache_before cache_after
        cache_before=$(find "$HOME/.cache/claude-templates" -type f | sort)
        
        # Run another dry-run to make sure cache is stable
        ./scripts/claude-template-sources.sh add another-dry-run "$repo2_dir" --dry-run >/dev/null 2>&1
        
        cache_after=$(find "$HOME/.cache/claude-templates" -type f | sort)
        assert_equals "$cache_before" "$cache_after" "Cache should not be modified by dry-run operations"
        
        # Verify only original source in configuration
        local sources_content
        sources_content=$(cat "$HOME/.config/claude-templates/sources.csv")
        assert_contains "cached-source" "$sources_content" "Original source should remain"
        assert_not_contains "dry-run-with-cache" "$sources_content" "Dry-run source should not be added"
        assert_not_contains "another-dry-run" "$sources_content" "Second dry-run source should not be added"
        
        local final_checksum
        final_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        assert_equals "$initial_checksum" "$final_checksum" "Dry-run should make no filesystem changes"
    )
}

test_dry_run_output_format_consistency() {
    (
        create_sandbox
        
        # Test dry-run output format consistency across commands
        local repo_dir
        repo_dir=$(create_test_repository "format-test")
        
        local initial_checksum
        initial_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        
        # Test dry-run add output format
        local add_output
        add_output=$(./scripts/claude-template-sources.sh add format-test "$repo_dir" --dry-run 2>&1)
        
        # Should have consistent dry-run indicators
        assert_contains "dryrun:add_template_source" "$add_output" "Add dry-run should print dryrun:add_template_source function name"
        
        # Actually add the source for remove test
        ./scripts/claude-template-sources.sh add format-test "$repo_dir" >/dev/null 2>&1
        
        # Test dry-run remove output format
        local remove_output
        remove_output=$(./scripts/claude-template-sources.sh remove format-test --dry-run 2>&1)
        
        assert_contains "dryrun:remove_template_source" "$remove_output" "Remove dry-run should print dryrun:remove_template_source function name"
        
        # Test dry-run list output format
        local list_output
        list_output=$(./scripts/claude-template-sources.sh list --dry-run 2>&1)
        
        assert_contains "dryrun:list_template_sources" "$list_output" "List dry-run should print dryrun:list_template_sources function name"
        
        # All dry-run outputs should contain function names
        assert_not_equals "" "$add_output" "Add dry-run should produce output"
        assert_not_equals "" "$remove_output" "Remove dry-run should produce output"
        assert_not_equals "" "$list_output" "List dry-run should produce output"
        
        local final_checksum
        final_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        assert_equals "$initial_checksum" "$final_checksum" "Dry-run should make no filesystem changes"
    )
}

# Register all test functions
register_tests \
    "test_dry_run_add_new_source" \
    "test_dry_run_add_duplicate_source" \
    "test_dry_run_add_validation_errors" \
    "test_dry_run_remove_existing_source" \
    "test_dry_run_remove_nonexistent_source" \
    "test_dry_run_remove_with_multiple_sources" \
    "test_dry_run_list_sources" \
    "test_dry_run_list_empty" \
    "test_dry_run_complex_repository_validation" \
    "test_dry_run_with_existing_cache" \
    "test_dry_run_output_format_consistency"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-template-sources.sh dry-run functionality" "$@"
fi