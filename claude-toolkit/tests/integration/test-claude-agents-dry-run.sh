#!/bin/bash
# test-claude-agents-dry-run.sh - Tests claude-agents.sh dry-run functionality
# 
# Purpose: Test scripts/claude-agents.sh dry-run mode across all commands
# Dependencies: None

source "$(dirname "$0")/../utils/test-harness.sh"

export DEBUG=true

test_dry_run_install() {
    (
        create_sandbox

        local output
        output=$(assert_command_succeeds "Dry run install should succeed" -- ./scripts/claude-agents.sh install --dry-run 2>&1)

        assert_contains "dryrun:" "$output" "Should show dry run markers"
        assert_directory_not_exists "$HOME/.claude/agents" "Should not create agents directory"
    )
}

test_dry_run_list() {
    (
        create_sandbox

        local output
        output=$(assert_command_succeeds "Dry run list should succeed" -- ./scripts/claude-agents.sh list --dry-run 2>&1)

        assert_contains "dryrun:" "$output" "Should show dry run markers"
    )
}

test_dry_run_uninstall() {
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

        local output
        output=$(assert_command_succeeds "Dry run uninstall should succeed" -- ./scripts/claude-agents.sh uninstall --source claude-toolkit --dry-run 2>&1)

        assert_contains "dryrun:" "$output" "Should show dry run markers"
        assert_file_exists "$HOME/.claude/agents/test-agent.md" "Should not remove files in dry run"
    )
}

test_dry_run_reinstall() {
    (
        create_sandbox

        local output
        output=$(assert_command_succeeds "Dry run reinstall should succeed" -- ./scripts/claude-agents.sh reinstall --dry-run 2>&1)

        assert_contains "dryrun:" "$output" "Should show dry run markers"
    )
}

register_tests \
    "test_dry_run_install" \
    "test_dry_run_list" \
    "test_dry_run_uninstall" \
    "test_dry_run_reinstall"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-agents.sh dry-run functionality" "$@"
fi