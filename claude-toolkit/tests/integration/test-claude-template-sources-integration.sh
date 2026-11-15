#!/bin/bash
# test-claude-template-sources-integration.sh - Tests claude-template-sources.sh integration scenarios
# 
# Purpose: Test scripts/claude-template-sources.sh integration with claude-slash.sh and end-to-end workflows
# Dependencies: None (creates own test scenarios)
# Approach: Test complete workflows and integration scenarios

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

# Helper function to create a test repository with multiple commands
create_multi_command_repository() {
    local repo_name="$1"
    local num_commands="${2:-3}"
    local repo_dir="$sandbox_dir/${repo_name}-repo"
    
    mkdir -p "$repo_dir"
    cd "$repo_dir"
    git init >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    mkdir -p slash-commands
    
    for i in $(seq 1 "$num_commands"); do
        cat > "slash-commands/${repo_name}-command-$i.md" << EOF
---
description: ${repo_name} command $i
source: ${repo_name}
argument-hint: <argument$i>
---

# ${repo_name} Command $i

This is command $i from the ${repo_name} source repository.

Usage: /${repo_name}-command-$i <argument$i>

Examples:
- /${repo_name}-command-$i example
- /${repo_name}-command-$i test
EOF
    done
    
    git add . && git commit -m "Initial commit with $num_commands commands" >/dev/null 2>&1
    cd "$original_dir"
    
    echo "$repo_dir"
}

test_integration_complete_workflow() {
    (
        create_sandbox
        
        # Test complete workflow: add source -> install commands -> list -> remove source
        
        # 1. Create and add multiple sources
        local team_alpha_repo team_beta_repo
        team_alpha_repo=$(create_multi_command_repository "team-alpha" 2)
        team_beta_repo=$(create_multi_command_repository "team-beta" 3)
        
        # Add sources
        assert_command_succeeds "Add team-alpha source" -- ./scripts/claude-template-sources.sh add team-alpha "$team_alpha_repo"
        assert_command_succeeds "Add team-beta source" -- ./scripts/claude-template-sources.sh add team-beta "$team_beta_repo"
        
        # 2. Verify sources are listed
        local sources_list
        sources_list=$(assert_command_succeeds "List sources after adding" -- ./scripts/claude-template-sources.sh list)
        assert_contains "team-alpha" "$sources_list" "Should list team-alpha source"
        assert_contains "team-beta" "$sources_list" "Should list team-beta source"
        
        # 3. Install commands using claude-slash.sh
        assert_command_succeeds "Install from team-alpha" -- ./scripts/claude-slash.sh install --source team-alpha
        assert_command_succeeds "Install from team-beta" -- ./scripts/claude-slash.sh install --source team-beta
        
        # 4. Verify commands are installed
        local installed_commands
        installed_commands=$(./scripts/claude-slash.sh list)
        assert_contains "team-alpha-command-1.md" "$installed_commands" "Should have team-alpha command 1"
        assert_contains "team-alpha-command-2.md" "$installed_commands" "Should have team-alpha command 2"
        assert_contains "team-beta-command-1.md" "$installed_commands" "Should have team-beta command 1"
        assert_contains "team-beta-command-2.md" "$installed_commands" "Should have team-beta command 2"
        assert_contains "team-beta-command-3.md" "$installed_commands" "Should have team-beta command 3"
        
        # 5. Remove one source
        assert_command_succeeds "Remove team-alpha source" -- ./scripts/claude-template-sources.sh remove team-alpha
        
        # 6. Verify source is removed but commands remain
        local sources_after_remove
        sources_after_remove=$(./scripts/claude-template-sources.sh list)
        assert_not_contains "team-alpha" "$sources_after_remove" "Should not list removed team-alpha source"
        assert_contains "team-beta" "$sources_after_remove" "Should still list team-beta source"
        
        # Commands should still be installed (removing source doesn't auto-uninstall)
        local commands_after_remove
        commands_after_remove=$(./scripts/claude-slash.sh list)
        assert_contains "team-alpha-command-1.md" "$commands_after_remove" "Commands should remain after source removal"
        assert_contains "team-beta-command-1.md" "$commands_after_remove" "Other source commands should remain"
    )
}

test_integration_source_updates() {
    (
        create_sandbox
        
        # Test workflow: add source -> install -> update source -> reinstall
        
        # 1. Create initial repository with 2 commands
        local repo_dir
        repo_dir=$(create_multi_command_repository "evolving-source" 2)
        
        # Add source and install
        assert_command_succeeds "Add evolving source" -- ./scripts/claude-template-sources.sh add evolving-source "$repo_dir"
        assert_command_succeeds "Install from evolving source" -- ./scripts/claude-slash.sh install --source evolving-source
        
        # Verify initial commands
        local initial_commands
        initial_commands=$(./scripts/claude-slash.sh list --source evolving-source)
        assert_contains "evolving-source-command-1.md" "$initial_commands" "Should have initial command 1"
        assert_contains "evolving-source-command-2.md" "$initial_commands" "Should have initial command 2"
        assert_not_contains "evolving-source-command-3.md" "$initial_commands" "Should not have command 3 initially"
        
        # 2. Update the repository (add new command)
        cd "$repo_dir"
        cat > "slash-commands/evolving-source-command-3.md" << 'EOF'
---
description: Evolving source command 3 (new)
source: evolving-source
---

# Evolving Source Command 3 (New)
This is a newly added command.
EOF
        
        git add . && git commit -m "Add command 3" >/dev/null 2>&1
        cd "$original_dir"
        
        # 3. Reinstall to get updates
        assert_command_succeeds "Reinstall to get updates" -- ./scripts/claude-slash.sh reinstall --source evolving-source
        
        # 4. Verify new command is available
        local updated_commands
        updated_commands=$(./scripts/claude-slash.sh list --source evolving-source)
        assert_contains "evolving-source-command-1.md" "$updated_commands" "Should still have command 1"
        assert_contains "evolving-source-command-2.md" "$updated_commands" "Should still have command 2"
        assert_contains "evolving-source-command-3.md" "$updated_commands" "Should now have new command 3"
    )
}

test_integration_multiple_sources_conflict_resolution() {
    (
        create_sandbox
        
        # Test multiple sources with potential naming conflicts
        
        # 1. Create repositories with similar command names
        local repo1_dir="$sandbox_dir/conflict-repo1"
        local repo2_dir="$sandbox_dir/conflict-repo2"
        
        # Repo 1
        mkdir -p "$repo1_dir"
        cd "$repo1_dir"
        git init >/dev/null 2>&1
        git config user.email "test@example.com"
        git config user.name "Test User"
        mkdir -p slash-commands
        
        cat > "slash-commands/deploy.md" << 'EOF'
---
description: Deploy command from source1
source: source1
---

# Deploy (Source 1)
Deploy from source1
EOF
        
        cat > "slash-commands/test.md" << 'EOF'
---
description: Test command from source1
source: source1
---

# Test (Source 1)
Test from source1
EOF
        
        git add . && git commit -m "Initial" >/dev/null 2>&1
        
        # Repo 2 with conflicting names
        mkdir -p "$repo2_dir"
        cd "$repo2_dir"
        git init >/dev/null 2>&1
        git config user.email "test@example.com"
        git config user.name "Test User"
        mkdir -p slash-commands
        
        cat > "slash-commands/deploy.md" << 'EOF'
---
description: Deploy command from source2
source: source2
---

# Deploy (Source 2)
Deploy from source2
EOF
        
        cat > "slash-commands/build.md" << 'EOF'
---
description: Build command from source2
source: source2
---

# Build (Source 2)
Build from source2
EOF
        
        git add . && git commit -m "Initial" >/dev/null 2>&1
        cd "$original_dir"
        
        # 2. Add both sources
        assert_command_succeeds "Add source1" -- ./scripts/claude-template-sources.sh add source1 "$repo1_dir"
        assert_command_succeeds "Add source2" -- ./scripts/claude-template-sources.sh add source2 "$repo2_dir"
        
        # 3. Install from both sources
        assert_command_succeeds "Install from source1" -- ./scripts/claude-slash.sh install --source source1
        assert_command_succeeds "Install from source2" -- ./scripts/claude-slash.sh install --source source2
        
        # 4. Verify conflict resolution
        local all_commands
        all_commands=$(./scripts/claude-slash.sh list)
        
        # Should have both deploy commands (with some conflict resolution)
        assert_contains "deploy" "$all_commands" "Should have deploy commands"
        assert_contains "test.md" "$all_commands" "Should have test command from source1"
        assert_contains "build.md" "$all_commands" "Should have build command from source2"
        
        # Verify sources are tracked correctly
        local source1_commands source2_commands
        source1_commands=$(./scripts/claude-slash.sh list --source source1)
        source2_commands=$(./scripts/claude-slash.sh list --source source2)
        
        assert_contains "source1" "$source1_commands" "Should identify source1 commands"
        assert_contains "source2" "$source2_commands" "Should identify source2 commands"
    )
}

test_integration_user_commands_preservation() {
    (
        create_sandbox
        
        # Test that user commands are preserved during source operations
        
        # 1. Create user commands first
        mkdir -p "$HOME/.claude/commands"
        
        cat > "$HOME/.claude/commands/my-personal-command.md" << 'EOF'
---
description: My personal command
---

# My Personal Command
This is my custom command.
EOF
        
        cat > "$HOME/.claude/commands/project-helper.md" << 'EOF'
---
description: Project helper command
argument-hint: <action>
---

# Project Helper
Personal project helper.
EOF
        
        # 2. Create and add source
        local repo_dir
        repo_dir=$(create_multi_command_repository "source-with-user" 2)
        assert_command_succeeds "Add source with user commands present" -- ./scripts/claude-template-sources.sh add source-with-user "$repo_dir"
        
        # 3. Install source commands
        assert_command_succeeds "Install source commands" -- ./scripts/claude-slash.sh install --source source-with-user
        
        # 4. Verify user commands are preserved
        local all_commands
        all_commands=$(./scripts/claude-slash.sh list)
        
        # User commands (no source field)
        assert_contains "my-personal-command.md" "$all_commands" "Should preserve user personal command"
        assert_contains "project-helper.md" "$all_commands" "Should preserve user project helper"
        
        # Source commands
        assert_contains "source-with-user-command-1.md" "$all_commands" "Should install source command 1"
        assert_contains "source-with-user-command-2.md" "$all_commands" "Should install source command 2"
        
        # 5. Filter by user source
        local user_commands
        user_commands=$(./scripts/claude-slash.sh list --source user)
        assert_contains "my-personal-command.md" "$user_commands" "Should show user commands in user filter"
        assert_contains "project-helper.md" "$user_commands" "Should show user commands in user filter"
        assert_not_contains "source-with-user" "$user_commands" "Should not show source commands in user filter"
        
        # 6. Remove source and verify user commands remain
        assert_command_succeeds "Remove source" -- ./scripts/claude-template-sources.sh remove source-with-user
        
        local commands_after_remove
        commands_after_remove=$(./scripts/claude-slash.sh list --source user)
        assert_contains "my-personal-command.md" "$commands_after_remove" "User commands should remain after source removal"
        assert_contains "project-helper.md" "$commands_after_remove" "User commands should remain after source removal"
    )
}

test_integration_source_name_conflicts_with_commands() {
    (
        create_sandbox
        
        # Test when source names might conflict with command names
        
        # 1. Create user command with name that matches a source
        mkdir -p "$HOME/.claude/commands"
        cat > "$HOME/.claude/commands/team-alpha.md" << 'EOF'
---
description: User command named team-alpha
---

# Team Alpha (User Command)
This is a user command that happens to have the same name as a source.
EOF
        
        # 2. Create actual team-alpha source
        local repo_dir
        repo_dir=$(create_multi_command_repository "team-alpha" 1)
        
        # 3. Add source (should handle name conflict gracefully)
        assert_command_succeeds "Add source with conflicting name" -- ./scripts/claude-template-sources.sh add team-alpha "$repo_dir"
        
        # 4. Install source commands
        assert_command_succeeds "Install from conflicting source" -- ./scripts/claude-slash.sh install --source team-alpha
        
        # 5. Verify both are present and distinguishable
        local all_commands
        all_commands=$(./scripts/claude-slash.sh list)
        
        # Should have both the user command and the source command
        assert_contains "team-alpha.md" "$all_commands" "Should have user command named team-alpha"
        assert_contains "team-alpha-command-1.md" "$all_commands" "Should have source command from team-alpha"
        
        # 6. Verify filtering works correctly
        local user_commands source_commands
        user_commands=$(./scripts/claude-slash.sh list --source user)
        source_commands=$(./scripts/claude-slash.sh list --source team-alpha)
        
        assert_contains "team-alpha.md" "$user_commands" "User command should appear in user filter"
        assert_not_contains "team-alpha-command-1.md" "$user_commands" "Source command should not appear in user filter"
        
        assert_not_contains "team-alpha.md" "$source_commands" "User command should not appear in source filter"
        assert_contains "team-alpha-command-1.md" "$source_commands" "Source command should appear in source filter"
    )
}

test_integration_cache_consistency() {
    (
        create_sandbox
        
        # Test cache consistency across operations
        
        # 1. Add multiple sources
        local repo1_dir repo2_dir repo3_dir
        repo1_dir=$(create_multi_command_repository "cache-test1" 2)
        repo2_dir=$(create_multi_command_repository "cache-test2" 1)
        repo3_dir=$(create_multi_command_repository "cache-test3" 3)
        
        assert_command_succeeds "Add cache-test1" -- ./scripts/claude-template-sources.sh add cache-test1 "$repo1_dir"
        assert_command_succeeds "Add cache-test2" -- ./scripts/claude-template-sources.sh add cache-test2 "$repo2_dir"
        assert_command_succeeds "Add cache-test3" -- ./scripts/claude-template-sources.sh add cache-test3 "$repo3_dir"
        
        # 2. Verify cache structure
        assert_directory_exists "$HOME/.cache/claude-templates" "Cache directory should exist"
        
        # 3. Install commands and verify they come from cache
        assert_command_succeeds "Install from cache-test1" -- ./scripts/claude-slash.sh install --source cache-test1
        assert_command_succeeds "Install from cache-test2" -- ./scripts/claude-slash.sh install --source cache-test2
        
        local installed_commands
        installed_commands=$(./scripts/claude-slash.sh list)
        assert_contains "cache-test1-command-1.md" "$installed_commands" "Should install from cached source 1"
        assert_contains "cache-test2-command-1.md" "$installed_commands" "Should install from cached source 2"
        
        # 4. Remove middle source and verify cache cleanup
        assert_command_succeeds "Remove cache-test2" -- ./scripts/claude-template-sources.sh remove cache-test2
        
        # 5. Verify remaining sources still work
        assert_command_succeeds "Install from remaining source" -- ./scripts/claude-slash.sh install --source cache-test3
        
        local final_commands
        final_commands=$(./scripts/claude-slash.sh list --source cache-test3)
        assert_contains "cache-test3-command-1.md" "$final_commands" "Should install from remaining cached source"
        
        # 6. List sources and verify consistency
        local final_sources
        final_sources=$(./scripts/claude-template-sources.sh list)
        assert_contains "cache-test1" "$final_sources" "Should list remaining source 1"
        assert_not_contains "cache-test2" "$final_sources" "Should not list removed source"
        assert_contains "cache-test3" "$final_sources" "Should list remaining source 3"
    )
}

test_integration_error_recovery() {
    (
        create_sandbox
        
        # Test error recovery and system state consistency
        
        # 1. Add valid source
        local valid_repo_dir
        valid_repo_dir=$(create_multi_command_repository "valid-source" 1)
        assert_command_succeeds "Add valid source" -- ./scripts/claude-template-sources.sh add valid-source "$valid_repo_dir"
        
        # 2. Try to add invalid source (should fail but not corrupt state)
        mkdir -p "$sandbox_dir/invalid-repo"
        echo "not a git repo" > "$sandbox_dir/invalid-repo/README.md"
        
        assert_command_fails "Add invalid source should fail" -- ./scripts/claude-template-sources.sh add invalid-source "$sandbox_dir/invalid-repo" 2>/dev/null
        
        # 3. Verify valid source is unaffected
        local sources_after_error
        sources_after_error=$(./scripts/claude-template-sources.sh list)
        assert_contains "valid-source" "$sources_after_error" "Valid source should remain after error"
        assert_not_contains "invalid-source" "$sources_after_error" "Invalid source should not be added"
        
        # 4. Verify system is still functional
        assert_command_succeeds "Install should still work" -- ./scripts/claude-slash.sh install --source valid-source
        
        local commands_after_error
        commands_after_error=$(./scripts/claude-slash.sh list --source valid-source)
        assert_contains "valid-source-command-1.md" "$commands_after_error" "Should install commands after error recovery"
        
        # 5. Add another valid source after error
        local recovery_repo_dir
        recovery_repo_dir=$(create_multi_command_repository "recovery-source" 1)
        assert_command_succeeds "Add source after error recovery" -- ./scripts/claude-template-sources.sh add recovery-source "$recovery_repo_dir"
        
        local final_sources
        final_sources=$(./scripts/claude-template-sources.sh list)
        assert_contains "valid-source" "$final_sources" "Should have original valid source"
        assert_contains "recovery-source" "$final_sources" "Should have new recovery source"
        assert_not_contains "invalid-source" "$final_sources" "Should not have failed source"
    )
}

# Register all test functions
register_tests \
    "test_integration_complete_workflow" \
    "test_integration_source_updates" \
    "test_integration_multiple_sources_conflict_resolution" \
    "test_integration_user_commands_preservation" \
    "test_integration_source_name_conflicts_with_commands" \
    "test_integration_cache_consistency" \
    "test_integration_error_recovery"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-template-sources.sh integration scenarios" "$@"
fi