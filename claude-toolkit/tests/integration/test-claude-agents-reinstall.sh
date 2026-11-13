#!/bin/bash
# test-claude-agents-reinstall.sh - Tests claude-agents.sh reinstall functionality
# 
# Purpose: Test scripts/claude-agents.sh reinstall functionality
# Dependencies: None

source "$(dirname "$0")/../utils/test-harness.sh"
source "$(dirname "$0")/../utils/file-utils.sh"
source "$(dirname "$0")/../utils/upstream-repo-utils.sh"

export DEBUG=true

test_suite_setup() {
    setup_upstream_repository
}

test_suite_teardown() {
    cleanup_upstream_repository
}

test_reinstall_replaces_modified_files() {
    (
        create_sandbox

        # Install initial agents
        assert_command_succeeds "Initial installation should succeed" -- ./scripts/claude-agents.sh install >/dev/null 2>&1

        # Find first installed agent and modify it
        local first_agent
        first_agent=$(find "$HOME/.claude/agents" -name "*.md" -type f | head -n 1)
        
        if [[ -n "$first_agent" ]]; then
            echo "User modification" >> "$first_agent"
            
            local checksum_before
            checksum_before=$(calculate_directory_checksum "$HOME/.claude/agents" "*.md")

            # Reinstall should replace modified files
            local reinstall_output
            reinstall_output=$(assert_command_succeeds "Reinstall should succeed" -- ./scripts/claude-agents.sh reinstall 2>&1)

            assert_contains "Successfully installed" "$reinstall_output" "Should report successful reinstall"

            local checksum_after
            checksum_after=$(calculate_directory_checksum "$HOME/.claude/agents" "*.md")

            assert_not_equals "$checksum_before" "$checksum_after" "Reinstall should replace modified files"
        fi
    )
}

test_reinstall_preserves_user_agents() {
    (
        create_sandbox

        mkdir -p "$HOME/.claude/agents"
        
        cat > "$HOME/.claude/agents/user-agent.md" << 'EOF'
---
name: user-agent
description: User agent
---

You are a user agent that should be preserved.
EOF

        local user_checksum_before
        user_checksum_before=$(calculate_file_checksum "$HOME/.claude/agents/user-agent.md")

        assert_command_succeeds "Reinstall should succeed" -- ./scripts/claude-agents.sh reinstall >/dev/null 2>&1

        local user_checksum_after
        user_checksum_after=$(calculate_file_checksum "$HOME/.claude/agents/user-agent.md")

        assert_equals "$user_checksum_before" "$user_checksum_after" "User agents should be preserved during reinstall"
    )
}

test_reinstall_removes_orphaned_files() {
    (
        setup_upstream_repository
        trap 'cleanup_upstream_repository' ERR
        trap 'cleanup_upstream_repository' EXIT
        (
            create_sandbox

            # Install initial agents
            assert_command_succeeds "Initial installation should succeed" -- ./scripts/claude-agents.sh install >/dev/null 2>&1

            # Create an orphaned file (agent with toolkit source but not in repository)
            cat > "$HOME/.claude/agents/orphaned-agent.md" << 'EOF'
---
name: orphaned-agent
description: Orphaned agent
source: claude-toolkit
---

You are an orphaned agent that should be removed.
EOF

            assert_file_exists "$HOME/.claude/agents/orphaned-agent.md" "Orphaned agent should exist before reinstall"

            # Reinstall should remove orphaned files
            local reinstall_output
            reinstall_output=$(assert_command_succeeds "Reinstall should succeed" -- ./scripts/claude-agents.sh reinstall 2>&1)

            assert_contains "removed orphaned file" "$reinstall_output" "Should report orphaned file removal"
            assert_file_not_exists "$HOME/.claude/agents/orphaned-agent.md" "Orphaned agent should be removed"
        )
    )
}

test_reinstall_dry_run() {
    (
        create_sandbox

        mkdir -p "$HOME/.claude/agents"
        
        cat > "$HOME/.claude/agents/test-agent.md" << 'EOF'
---
name: test-agent
description: Test agent
source: claude-toolkit
---

You are a test agent.
EOF

        local dry_run_output
        dry_run_output=$(assert_command_succeeds "Reinstall dry run should succeed" -- ./scripts/claude-agents.sh reinstall --dry-run 2>&1)

        assert_contains "dryrun:" "$dry_run_output" "Should show dry run markers"
    )
}

register_tests \
    "test_reinstall_replaces_modified_files" \
    "test_reinstall_preserves_user_agents" \
    "test_reinstall_removes_orphaned_files" \
    "test_reinstall_dry_run"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-agents.sh reinstall functionality" "$@"
fi