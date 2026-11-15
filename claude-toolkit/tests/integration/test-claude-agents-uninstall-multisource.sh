#!/bin/bash
# test-claude-agents-uninstall-multisource.sh - Tests claude-agents.sh uninstall with multiple sources
# 
# Purpose: Test scripts/claude-agents.sh uninstall functionality with multiple source configurations
# Dependencies: None

source "$(dirname "$0")/../utils/test-harness.sh"
source "$(dirname "$0")/../utils/file-utils.sh"

export DEBUG=true

test_uninstall_multiple_sources_comma_separated() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/agents"
        
        # Create agents from different sources
        cat > "$HOME/.claude/agents/toolkit-agent.md" << 'EOF'
---
name: toolkit-agent
description: Toolkit agent
source: claude-toolkit
---

You are a toolkit agent.
EOF
        
        cat > "$HOME/.claude/agents/alpha-agent.md" << 'EOF'
---
name: alpha-agent
description: Team alpha agent
source: team-alpha
---

You are a team alpha agent.
EOF
        
        cat > "$HOME/.claude/agents/beta-agent.md" << 'EOF'
---
name: beta-agent
description: Team beta agent
source: team-beta
---

You are a team beta agent.
EOF
        
        cat > "$HOME/.claude/agents/user-agent.md" << 'EOF'
---
name: user-agent
description: User agent
---

You are a user agent.
EOF
        
        # Uninstall multiple specific sources
        local uninstall_output
        uninstall_output=$(assert_command_succeeds "Uninstall multiple sources should succeed" -- ./scripts/claude-agents.sh uninstall --source claude-toolkit,team-alpha --yes 2>&1)
        
        assert_contains "Successfully uninstalled" "$uninstall_output" "Should report successful uninstall"
        
        # Check which files were removed
        assert_file_not_exists "$HOME/.claude/agents/toolkit-agent.md" "Toolkit agent should be removed"
        assert_file_not_exists "$HOME/.claude/agents/alpha-agent.md" "Team alpha agent should be removed"
        assert_file_exists "$HOME/.claude/agents/beta-agent.md" "Team beta agent should remain"
        assert_file_exists "$HOME/.claude/agents/user-agent.md" "User agent should remain"
    )
}

test_uninstall_all_vs_specific_sources() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/agents"
        
        # Create agents from different sources
        for source in claude-toolkit team-alpha team-beta; do
            cat > "$HOME/.claude/agents/${source}-agent.md" << EOF
---
name: ${source}-agent
description: ${source} agent
source: ${source}
---

You are a ${source} agent.
EOF
        done
        
        cat > "$HOME/.claude/agents/user-agent.md" << 'EOF'
---
name: user-agent
description: User agent
---

You are a user agent.
EOF
        
        # Test that 'all' removes all non-user agents
        local all_uninstall_output
        all_uninstall_output=$(assert_command_succeeds "Uninstall all should succeed" -- ./scripts/claude-agents.sh uninstall --source all --yes 2>&1)
        
        assert_contains "Successfully uninstalled" "$all_uninstall_output" "Should report successful uninstall of all sources"
        
        # Check that all non-user agents are removed
        assert_file_not_exists "$HOME/.claude/agents/claude-toolkit-agent.md" "Toolkit agent should be removed"
        assert_file_not_exists "$HOME/.claude/agents/team-alpha-agent.md" "Team alpha agent should be removed"
        assert_file_not_exists "$HOME/.claude/agents/team-beta-agent.md" "Team beta agent should be removed"
        assert_file_exists "$HOME/.claude/agents/user-agent.md" "User agent should remain"
    )
}

test_uninstall_mixed_source_list() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/agents"
        
        # Create agents from different sources including some that don't exist
        cat > "$HOME/.claude/agents/toolkit-agent.md" << 'EOF'
---
name: toolkit-agent
description: Toolkit agent
source: claude-toolkit
---

You are a toolkit agent.
EOF
        
        cat > "$HOME/.claude/agents/alpha-agent.md" << 'EOF'
---
name: alpha-agent
description: Team alpha agent
source: team-alpha
---

You are a team alpha agent.
EOF
        
        # Uninstall mix of existing and non-existing sources
        local uninstall_output
        uninstall_output=$(assert_command_succeeds "Uninstall mixed sources should succeed" -- ./scripts/claude-agents.sh uninstall --source claude-toolkit,nonexistent-source,team-alpha --yes 2>&1)
        
        # Should succeed and remove existing agents
        assert_file_not_exists "$HOME/.claude/agents/toolkit-agent.md" "Toolkit agent should be removed"
        assert_file_not_exists "$HOME/.claude/agents/alpha-agent.md" "Team alpha agent should be removed"
    )
}

test_uninstall_source_validation_errors() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/agents"
        
        cat > "$HOME/.claude/agents/user-agent.md" << 'EOF'
---
name: user-agent
description: User agent
---

You are a user agent.
EOF
        
        # Test that user source cannot be included in uninstall lists
        local user_in_list_output
        user_in_list_output=$(assert_command_fails "User in source list should fail" -- ./scripts/claude-agents.sh uninstall --source claude-toolkit,user,team-alpha --yes 2>&1)
        
        assert_contains "Cannot uninstall user files" "$user_in_list_output" "Should block user files in source list"
        
        # Test user-only source
        local user_only_output
        user_only_output=$(assert_command_fails "User-only source should fail" -- ./scripts/claude-agents.sh uninstall --source user --yes 2>&1)
        
        assert_contains "Cannot uninstall user files" "$user_only_output" "Should block user-only uninstall"
        
        # Ensure user agent still exists
        assert_file_exists "$HOME/.claude/agents/user-agent.md" "User agent should still exist"
    )
}

test_uninstall_empty_source_list() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/agents"
        
        cat > "$HOME/.claude/agents/toolkit-agent.md" << 'EOF'
---
name: toolkit-agent
description: Toolkit agent
source: claude-toolkit
---

You are a toolkit agent.
EOF
        
        # Test uninstall with empty source (should use default 'all')
        local empty_source_output
        empty_source_output=$(assert_command_succeeds "Empty source should default to all" -- ./scripts/claude-agents.sh uninstall --yes 2>&1)
        
        assert_contains "Successfully uninstalled" "$empty_source_output" "Should succeed with default source"
        assert_file_not_exists "$HOME/.claude/agents/toolkit-agent.md" "Toolkit agent should be removed"
    )
}

test_uninstall_source_with_spaces() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/agents"
        
        # Create agents with sources that might have special handling
        cat > "$HOME/.claude/agents/special-agent.md" << 'EOF'
---
name: special-agent
description: Special agent
source: my-special-source
---

You are a special agent.
EOF
        
        # Test source with special characters (should work)
        local special_output
        special_output=$(assert_command_succeeds "Special source characters should work" -- ./scripts/claude-agents.sh uninstall --source my-special-source --yes 2>&1)
        
        assert_file_not_exists "$HOME/.claude/agents/special-agent.md" "Special source agent should be removed"
    )
}

register_tests \
    "test_uninstall_multiple_sources_comma_separated" \
    "test_uninstall_all_vs_specific_sources" \
    "test_uninstall_mixed_source_list" \
    "test_uninstall_source_validation_errors" \
    "test_uninstall_empty_source_list" \
    "test_uninstall_source_with_spaces"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-agents.sh multisource uninstall functionality" "$@"
fi