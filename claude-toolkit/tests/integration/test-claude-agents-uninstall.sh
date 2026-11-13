#!/bin/bash
# test-claude-agents-uninstall.sh - Tests claude-agents.sh uninstall functionality
# 
# Purpose: Test scripts/claude-agents.sh uninstall functionality according to design
# Dependencies: None

source "$(dirname "$0")/../utils/test-harness.sh"
source "$(dirname "$0")/../utils/file-utils.sh"

export DEBUG=true

test_uninstall_toolkit_agents() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/agents"
        
        # Create toolkit agents
        cat > "$HOME/.claude/agents/toolkit-debugger.md" << 'EOF'
---
name: toolkit-debugger
description: Toolkit debugger agent
source: claude-toolkit
---

You are a debugging specialist.
EOF
        
        cat > "$HOME/.claude/agents/toolkit-reviewer.md" << 'EOF'
---
name: toolkit-reviewer
description: Toolkit code reviewer agent
source: claude-toolkit
---

You are a code review specialist.
EOF
        
        # Create user agent (should be preserved)
        cat > "$HOME/.claude/agents/user-helper.md" << 'EOF'
---
name: user-helper
description: Personal helper agent
---

You are a personal assistant.
EOF
        
        assert_file_exists "$HOME/.claude/agents/toolkit-debugger.md" "Toolkit debugger should exist before uninstall"
        assert_file_exists "$HOME/.claude/agents/toolkit-reviewer.md" "Toolkit reviewer should exist before uninstall"
        assert_file_exists "$HOME/.claude/agents/user-helper.md" "User helper should exist before uninstall"
        
        # Uninstall toolkit agents with auto-accept
        local uninstall_output
        uninstall_output=$(assert_command_succeeds "Uninstall toolkit agents should succeed" -- ./scripts/claude-agents.sh uninstall --source claude-toolkit --yes 2>&1)
        
        assert_contains "Successfully uninstalled" "$uninstall_output" "Should report successful uninstall"
        
        assert_file_not_exists "$HOME/.claude/agents/toolkit-debugger.md" "Toolkit debugger should be removed"
        assert_file_not_exists "$HOME/.claude/agents/toolkit-reviewer.md" "Toolkit reviewer should be removed"
        assert_file_exists "$HOME/.claude/agents/user-helper.md" "User helper should be preserved"
    )
}

test_uninstall_all_sources_preserves_user() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/agents"
        
        # Create agents from multiple sources
        cat > "$HOME/.claude/agents/toolkit-agent.md" << 'EOF'
---
name: toolkit-agent
description: Toolkit agent
source: claude-toolkit
---

You are a toolkit agent.
EOF
        
        cat > "$HOME/.claude/agents/team-agent.md" << 'EOF'
---
name: team-agent
description: Team agent
source: team-alpha
---

You are a team agent.
EOF
        
        cat > "$HOME/.claude/agents/user-agent.md" << 'EOF'
---
name: user-agent
description: User agent
---

You are a user agent.
EOF
        
        assert_file_exists "$HOME/.claude/agents/toolkit-agent.md" "Toolkit agent should exist before uninstall"
        assert_file_exists "$HOME/.claude/agents/team-agent.md" "Team agent should exist before uninstall"
        assert_file_exists "$HOME/.claude/agents/user-agent.md" "User agent should exist before uninstall"
        
        # Uninstall all non-user agents
        local uninstall_output
        uninstall_output=$(assert_command_succeeds "Uninstall all should succeed" -- ./scripts/claude-agents.sh uninstall --source all --yes 2>&1)
        
        assert_contains "Successfully uninstalled" "$uninstall_output" "Should report successful uninstall"
        
        assert_file_not_exists "$HOME/.claude/agents/toolkit-agent.md" "Toolkit agent should be removed"
        assert_file_not_exists "$HOME/.claude/agents/team-agent.md" "Team agent should be removed"
        assert_file_exists "$HOME/.claude/agents/user-agent.md" "User agent should be preserved"
    )
}

test_uninstall_user_agents_blocked() {
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
        
        # Attempt to uninstall user agents should fail
        local uninstall_output
        uninstall_output=$(assert_command_fails "Uninstall user agents should fail" -- ./scripts/claude-agents.sh uninstall --source user --yes 2>&1)
        
        assert_contains "Cannot uninstall user files" "$uninstall_output" "Should block user file uninstall"
        assert_file_exists "$HOME/.claude/agents/user-agent.md" "User agent should still exist"
    )
}

test_uninstall_confirmation_prompt() {
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
        
        # Test cancellation (simulate 'n' response)
        echo "n" | assert_command_fails "Uninstall should be cancelled" -- ./scripts/claude-agents.sh uninstall --source claude-toolkit 2>&1
        
        assert_file_exists "$HOME/.claude/agents/toolkit-agent.md" "Agent should still exist after cancellation"
        
        # Test acceptance (simulate 'y' response)
        echo "y" | assert_command_succeeds "Uninstall should proceed" -- ./scripts/claude-agents.sh uninstall --source claude-toolkit 2>&1
        
        assert_file_not_exists "$HOME/.claude/agents/toolkit-agent.md" "Agent should be removed after acceptance"
    )
}

test_uninstall_nonexistent_source() {
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
        
        # Uninstall from nonexistent source should succeed but do nothing
        local uninstall_output
        uninstall_output=$(assert_command_succeeds "Uninstall nonexistent source should succeed" -- ./scripts/claude-agents.sh uninstall --source nonexistent-source --yes 2>&1)
        
        assert_contains "nothing to uninstall" "$uninstall_output" "Should report nothing to uninstall"
        assert_file_exists "$HOME/.claude/agents/toolkit-agent.md" "Existing agents should remain"
    )
}

test_uninstall_empty_directory() {
    (
        create_sandbox
        
        # Test uninstall with no agents directory
        local uninstall_output
        uninstall_output=$(assert_command_succeeds "Uninstall empty should succeed" -- ./scripts/claude-agents.sh uninstall --source all --yes 2>&1)
        
        assert_contains "nothing to uninstall" "$uninstall_output" "Should report nothing to uninstall"
        
        # Test uninstall with empty agents directory
        mkdir -p "$HOME/.claude/agents"
        
        local empty_uninstall_output
        empty_uninstall_output=$(assert_command_succeeds "Uninstall empty directory should succeed" -- ./scripts/claude-agents.sh uninstall --source all --yes 2>&1)
        
        assert_contains "nothing to uninstall" "$empty_uninstall_output" "Should report nothing to uninstall from empty directory"
    )
}

test_uninstall_readonly_files() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/agents"
        
        cat > "$HOME/.claude/agents/readonly-agent.md" << 'EOF'
---
name: readonly-agent
description: Read-only agent
source: claude-toolkit
---

You are a read-only agent.
EOF
        
        # Make file read-only
        chmod 444 "$HOME/.claude/agents/readonly-agent.md"
        
        # Uninstall should fail for read-only files
        local uninstall_output
        uninstall_output=$(assert_command_fails "Uninstall read-only should fail" -- ./scripts/claude-agents.sh uninstall --source claude-toolkit --yes 2>&1)
        
        assert_contains "Read-only file may not be uninstalled" "$uninstall_output" "Should report read-only file error"
        assert_file_exists "$HOME/.claude/agents/readonly-agent.md" "Read-only file should still exist"
        
        # Clean up
        chmod 644 "$HOME/.claude/agents/readonly-agent.md" 2>/dev/null || true
    )
}

test_uninstall_permission_errors() {
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
        
        # Make agents directory read-only to test permission validation
        chmod 444 "$HOME/.claude/agents"
        
        local uninstall_output
        uninstall_output=$(assert_command_fails "Uninstall should fail with permission issues" -- ./scripts/claude-agents.sh uninstall --source claude-toolkit --yes 2>&1)
        
        assert_contains "Cannot write to" "$uninstall_output" "Should report permission error"
        
        # Restore permissions for cleanup
        chmod 755 "$HOME/.claude/agents" 2>/dev/null || true
    )
}

test_uninstall_dry_run() {
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
        
        # Test dry run mode
        local dry_run_output
        dry_run_output=$(assert_command_succeeds "Uninstall dry run should succeed" -- ./scripts/claude-agents.sh uninstall --source claude-toolkit --dry-run 2>&1)
        
        assert_contains "dryrun:" "$dry_run_output" "Should show dry run markers"
        assert_file_exists "$HOME/.claude/agents/toolkit-agent.md" "Agent should still exist in dry run"
    )
}

test_uninstall_multiple_sources() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/agents"
        
        # Create agents from multiple sources
        cat > "$HOME/.claude/agents/toolkit-agent.md" << 'EOF'
---
name: toolkit-agent
description: Toolkit agent
source: claude-toolkit
---

You are a toolkit agent.
EOF
        
        cat > "$HOME/.claude/agents/team-agent.md" << 'EOF'
---
name: team-agent
description: Team agent
source: team-alpha
---

You are a team agent.
EOF
        
        cat > "$HOME/.claude/agents/other-agent.md" << 'EOF'
---
name: other-agent
description: Other agent
source: team-beta
---

You are another team agent.
EOF
        
        # Uninstall multiple specific sources
        local uninstall_output
        uninstall_output=$(assert_command_succeeds "Uninstall multiple sources should succeed" -- ./scripts/claude-agents.sh uninstall --source claude-toolkit,team-alpha --yes 2>&1)
        
        assert_contains "Successfully uninstalled" "$uninstall_output" "Should report successful uninstall"
        
        assert_file_not_exists "$HOME/.claude/agents/toolkit-agent.md" "Toolkit agent should be removed"
        assert_file_not_exists "$HOME/.claude/agents/team-agent.md" "Team alpha agent should be removed"
        assert_file_exists "$HOME/.claude/agents/other-agent.md" "Team beta agent should remain"
    )
}

# Register all test functions
register_tests \
    "test_uninstall_toolkit_agents" \
    "test_uninstall_all_sources_preserves_user" \
    "test_uninstall_user_agents_blocked" \
    "test_uninstall_confirmation_prompt" \
    "test_uninstall_nonexistent_source" \
    "test_uninstall_empty_directory" \
    "test_uninstall_readonly_files" \
    "test_uninstall_permission_errors" \
    "test_uninstall_dry_run" \
    "test_uninstall_multiple_sources"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-agents.sh uninstall functionality" "$@"
fi