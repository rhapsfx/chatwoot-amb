#!/bin/bash
# test-claude-agents-install.sh - Tests claude-agents.sh install functionality
# 
# Purpose: Test scripts/claude-agents.sh installation functionality according to streamlined design
# Dependencies: None

source "$(dirname "$0")/../utils/test-harness.sh"
source "$(dirname "$0")/../utils/file-utils.sh"
source "$(dirname "$0")/../utils/upstream-repo-utils.sh"

# Enable debug mode for all tests to capture debug messages
export DEBUG=true

# Standard test suite setup function for upstream repository tests
test_suite_setup() {
    setup_upstream_repository
}

# Standard test suite teardown function for upstream repository tests
test_suite_teardown() {
    cleanup_upstream_repository
}

test_install() {
    (
        create_sandbox

        local install_output
        install_output=$(assert_command_succeeds "Installation should succeed" -- ./scripts/claude-agents.sh install 2>&1)
        
        assert_directory_exists "$HOME/.claude/agents" "Agents directory should be created"
        
        # Should successfully install agents from source
        assert_contains "Successfully installed" "$install_output" "Should report successful installation"
        assert_contains "architect.md" "$install_output" "Should install architect.md"

        local checksum_before
        checksum_before=$(calculate_directory_checksum "$HOME/.claude/agents" "*.md")

        local install_output_second
        install_output_second=$(assert_command_succeeds "Second installation should succeed" -- ./scripts/claude-agents.sh install 2>&1)

        # Should report that files are already installed on second run
        assert_contains "All files already installed" "$install_output_second" "Should report files already installed on second run"

        local checksum_after
        checksum_after=$(calculate_directory_checksum "$HOME/.claude/agents" "*.md")

        assert_equals "$checksum_before" "$checksum_after" "Install should be idempotent"
    )
}

test_install_adds_new_files() {
    (
        setup_upstream_repository
        trap 'cleanup_upstream_repository' ERR
        trap 'cleanup_upstream_repository' EXIT
        (
            create_sandbox

            assert_command_succeeds "Installation should succeed" -- ./scripts/claude-agents.sh install >/dev/null 2>&1

            local checksum_before
            checksum_before=$(calculate_directory_checksum "$HOME/.claude/agents" "*.md")

            mkdir -p "$DEFAULT_REMOTE_REPOSITORY/agents"
            cat > "$DEFAULT_REMOTE_REPOSITORY/agents/my-agent.md" << 'EOF'
---
name: my-agent
description: My custom agent for testing
source: claude-toolkit
---

You are a test agent for validation purposes.

When invoked:
1. Analyze the request
2. Provide helpful responses
3. Maintain professionalism

Focus on delivering accurate and concise information.
EOF
            git -C "$DEFAULT_REMOTE_REPOSITORY" add .
            git -C "$DEFAULT_REMOTE_REPOSITORY" commit -m "Added new agent" >/dev/null 2>&1

            assert_file_not_exists "$HOME/.claude/agents/my-agent.md" "New agent should not be available before second install"

            local install_output
            install_output=$(assert_command_succeeds "Second installation should succeed" -- ./scripts/claude-agents.sh install 2>&1)

            assert_not_contains "All files already installed" "$install_output" "Should not signal that all files are already installed"

            local checksum_after
            checksum_after=$(calculate_directory_checksum "$HOME/.claude/agents" "*.md")

            assert_not_equals "$checksum_before" "$checksum_after" "Install should update agents"

            assert_file_exists "$HOME/.claude/agents/my-agent.md" "New agent should be available after second install"
        )
    )
}

test_install_fails_on_changed_files() {
    (
        setup_upstream_repository
        trap 'cleanup_upstream_repository' ERR
        trap 'cleanup_upstream_repository' EXIT
        (
            create_sandbox

            # Create an agent in the upstream repository first
            mkdir -p "$DEFAULT_REMOTE_REPOSITORY/agents"
            cat > "$DEFAULT_REMOTE_REPOSITORY/agents/test-agent.md" << 'EOF'
---
name: test-agent
description: Test agent for change detection
source: claude-toolkit
---

You are a test agent for validating change detection.
EOF
            git -C "$DEFAULT_REMOTE_REPOSITORY" add .
            git -C "$DEFAULT_REMOTE_REPOSITORY" commit -m "Added test agent" >/dev/null 2>&1

            assert_command_succeeds "First installation should succeed" -- ./scripts/claude-agents.sh install >/dev/null 2>&1

            local checksum_before
            checksum_before=$(calculate_directory_checksum "$HOME/.claude/agents" "*.md")

            # Find the installed agent file
            local agent_file="$HOME/.claude/agents/test-agent.md"
            assert_file_exists "$agent_file" "Test agent should be installed"
            
            echo "User change 1" >>"$agent_file"

            local checksum_after_change
            checksum_after_change=$(calculate_directory_checksum "$HOME/.claude/agents" "*.md")

            assert_not_equals "$checksum_before" "$checksum_after_change" "User change should be detected after modifying the agent file"

            local install_output
            install_output=$(assert_command_fails "Second installation should fail" -- ./scripts/claude-agents.sh install 2>&1)

            local checksum_after
            checksum_after=$(calculate_directory_checksum "$HOME/.claude/agents" "*.md")

            assert_equals "$checksum_after_change" "$checksum_after" "Failed install should not change installed agents"
        )
    )
}

test_install_succeeds_on_upstream_changes() {
    (
        setup_upstream_repository
        trap 'cleanup_upstream_repository' ERR
        trap 'cleanup_upstream_repository' EXIT
        (
            create_sandbox

            # Create an agent in the upstream repository first
            mkdir -p "$DEFAULT_REMOTE_REPOSITORY/agents"
            cat > "$DEFAULT_REMOTE_REPOSITORY/agents/test-agent.md" << 'EOF'
---
name: test-agent
description: Test agent for upstream change detection
source: claude-toolkit
---

You are a test agent for validating upstream change detection.
EOF
            git -C "$DEFAULT_REMOTE_REPOSITORY" add .
            git -C "$DEFAULT_REMOTE_REPOSITORY" commit -m "Added test agent" >/dev/null 2>&1

            # First installation
            assert_command_succeeds "First installation should succeed" -- ./scripts/claude-agents.sh install >/dev/null 2>&1

            local checksum_before
            checksum_before=$(calculate_file_checksum "$HOME/.claude/agents/test-agent.md")

            # Simulate upstream change by modifying the agent file in the upstream repository
            echo "" >> "$DEFAULT_REMOTE_REPOSITORY/agents/test-agent.md"
            echo "Updated instructions from upstream: Focus on enhanced validation." >> "$DEFAULT_REMOTE_REPOSITORY/agents/test-agent.md"
            git -C "$DEFAULT_REMOTE_REPOSITORY" add .
            git -C "$DEFAULT_REMOTE_REPOSITORY" commit -m "Updated test agent" >/dev/null 2>&1

            # Second installation should succeed and update the file
            local install_output
            install_output=$(assert_command_succeeds "Second installation should succeed with upstream changes" -- ./scripts/claude-agents.sh install 2>&1)

            assert_not_contains "All files already installed" "$install_output" "Should not signal that all files are already installed"
            assert_not_contains "contains user changes" "$install_output" "Should not report user changes when user hasn't modified file"

            local checksum_after
            checksum_after=$(calculate_file_checksum "$HOME/.claude/agents/test-agent.md")

            assert_not_equals "$checksum_before" "$checksum_after" "File should be updated with upstream changes"

            # Verify the upstream content is present
            assert_file_contains "$HOME/.claude/agents/test-agent.md" "Updated instructions from upstream: Focus on enhanced validation." "File should contain upstream changes"
        )
    )
}

test_install_succeeds_on_orphaned_tracked_files() {
    (
        setup_upstream_repository
        trap 'cleanup_upstream_repository' ERR
        trap 'cleanup_upstream_repository' EXIT
        (
            create_sandbox

            # First, add an agent to the upstream repository and install it
            mkdir -p "$DEFAULT_REMOTE_REPOSITORY/agents"
            cat > "$DEFAULT_REMOTE_REPOSITORY/agents/temp-agent.md" << 'EOF'
---
name: temp-agent
description: Temporary agent for removal test
source: claude-toolkit
---

You are a temporary agent that will be removed.
EOF
            git -C "$DEFAULT_REMOTE_REPOSITORY" add .
            git -C "$DEFAULT_REMOTE_REPOSITORY" commit -m "Added temp agent" >/dev/null 2>&1

            # Install the agent - this creates snapshot
            assert_command_succeeds "First installation should succeed" -- ./scripts/claude-agents.sh install >/dev/null 2>&1
            assert_file_exists "$HOME/.claude/agents/temp-agent.md" "Temp agent should be installed"

            # Now remove the agent from the upstream repository (but architect.md remains)
            rm "$DEFAULT_REMOTE_REPOSITORY/agents/temp-agent.md"
            git -C "$DEFAULT_REMOTE_REPOSITORY" add .
            git -C "$DEFAULT_REMOTE_REPOSITORY" commit -m "Removed temp agent" >/dev/null 2>&1

            # Second installation should succeed and remove the orphaned file
            local install_output
            install_output=$(assert_command_succeeds "Second installation should succeed and remove orphaned file" -- ./scripts/claude-agents.sh install 2>&1)
            
            # Should report orphaned file removal
            assert_contains "removed orphaned file: temp-agent.md" "$install_output" "Should report orphaned file removal"
            assert_file_not_exists "$HOME/.claude/agents/temp-agent.md" "Orphaned file should be removed"
        )
    )
}

test_install_preserves_user_agents() {
    (
        create_sandbox

        mkdir -p "$HOME/.claude/agents"
        
        cat > "$HOME/.claude/agents/my-user-agent.md" << 'EOF'
---
name: my-user-agent
description: A user-created agent for personal use
---

You are a custom user agent that should be preserved during installation.

When invoked:
1. Help with personal tasks
2. Provide customized responses
3. Maintain user preferences

Focus on personalized assistance.
EOF

        assert_file_exists "$HOME/.claude/agents/my-user-agent.md" "User agent should exist before installation"

        local checksum_before
        checksum_before=$(calculate_file_checksum "$HOME/.claude/agents/my-user-agent.md")

        assert_command_succeeds "Installation should succeed with user agents present" -- ./scripts/claude-agents.sh install >/dev/null 2>&1

        local checksum_after
        checksum_after=$(calculate_file_checksum "$HOME/.claude/agents/my-user-agent.md")

        assert_equals "$checksum_before" "$checksum_after" "User agent files should remain unchanged after installation"
    )
}

test_install_handles_agent_conflicts() {
    (
        create_sandbox

        mkdir -p "$HOME/.claude/agents"
        
        cat > "$HOME/.claude/agents/debugger.md" << 'EOF'
---
name: debugger
description: User's custom debugger agent
---

You are a user-created debugger agent that conflicts with the toolkit version.

When invoked:
1. Analyze code issues with user's preferred methodology
2. Provide personalized debugging tips
3. Use custom debugging workflow

Focus on user-specific debugging approaches.
EOF

        assert_file_exists "$HOME/.claude/agents/debugger.md" "User debugger agent should exist before installation"

        local checksum_before
        checksum_before=$(calculate_file_checksum "$HOME/.claude/agents/debugger.md")

        assert_command_succeeds "Installation should succeed" -- ./scripts/claude-agents.sh install >/dev/null 2>&1
        
        local checksum_after
        checksum_after=$(calculate_file_checksum "$HOME/.claude/agents/debugger.md")
        
        assert_equals "$checksum_before" "$checksum_after" "User agent files should remain unchanged after installation"

        # Check if the toolkit version was installed with a renamed filename
        local toolkit_agent
        toolkit_agent=$(find "$HOME/.claude/agents" -name "*debugger*claude-toolkit*.md" -type f | head -n 1)
        
        if [[ -n "$toolkit_agent" ]]; then
            assert_file_exists "$toolkit_agent" "Installed agent should be renamed"
        fi
    )
}

test_install_error_handling_permission_issues() {
    (
        create_sandbox

        mkdir -p "$HOME/.claude"
        chmod 444 "$HOME/.claude"

        assert_command_fails "Installation should fail with permission issues" -- ./scripts/claude-agents.sh install >/dev/null 2>&1

        chmod 755 "$HOME/.claude" 2>/dev/null || true
        rm -rf "$HOME/.claude" 2>/dev/null || true

        # Create the agents directory structure but make the agents directory read-only
        mkdir -p "$HOME/.claude/agents"
        chmod 444 "$HOME/.claude/agents"
        
        assert_command_fails "Installation should fail with read-only agents directory" -- ./scripts/claude-agents.sh install >/dev/null 2>&1
        
        chmod 755 "$HOME/.claude/agents" 2>/dev/null || true
    )
}

test_install_with_source_option() {
    (
        create_sandbox

        # Test install with specific source - should find and install architect.md
        local install_output
        install_output=$(assert_command_succeeds "Installation with source should succeed" -- ./scripts/claude-agents.sh install --source claude-toolkit 2>&1)
        
        assert_directory_exists "$HOME/.claude/agents" "Agents directory should be created"
        assert_contains "Successfully installed" "$install_output" "Should report successful installation"
        assert_contains "architect.md" "$install_output" "Should install architect.md from specified source"

        # Verify that architect was installed
        assert_file_exists "$HOME/.claude/agents/architect.md" "Architect agent should be installed"
    )
}

test_install_dry_run() {
    (
        create_sandbox

        local dry_run_output
        dry_run_output=$(assert_command_succeeds "Dry run should succeed" -- ./scripts/claude-agents.sh install --dry-run 2>&1)

        # In dry run mode, the script should exit early without processing
        # The exact output may vary but should not create directories
        assert_directory_not_exists "$HOME/.claude/agents" "Should not create agents directory in dry run"
    )
}

test_install_fails_on_orphaned_user_created_files() {
    (
        create_sandbox

        # Create a user agent that looks like it's from toolkit but was user-created
        mkdir -p "$HOME/.claude/agents"
        cat > "$HOME/.claude/agents/my-fake-toolkit-agent.md" << 'EOF'
---
name: my-fake-toolkit-agent
description: User agent masquerading as toolkit
source: claude-toolkit
---

You are a user-created agent that claims to be from toolkit.

When invoked:
1. Handle user tasks
2. Provide responses
3. Maintain user preferences

Focus on personalized assistance.
EOF

        # Get checksum before installation attempt
        local checksum_before
        checksum_before=$(calculate_file_checksum "$HOME/.claude/agents/my-fake-toolkit-agent.md")

        # Try to install - should fail because orphaned file is not tracked in snapshot
        local install_output
        install_output=$(assert_command_fails "Installation should fail with untracked orphaned file" -- ./scripts/claude-agents.sh install 2>&1)

        assert_contains "orphaned installed file: my-fake-toolkit-agent.md (not tracked - possibly user-created)" "$install_output" "Should detect untracked orphaned file"
        
        # Verify file is unchanged using checksum
        local checksum_after
        checksum_after=$(calculate_file_checksum "$HOME/.claude/agents/my-fake-toolkit-agent.md")
        assert_equals "$checksum_before" "$checksum_after" "User-created file should remain unchanged after failed install"
    )
}

test_install_fails_on_orphaned_modified_files() {
    (
        setup_upstream_repository
        trap 'cleanup_upstream_repository' ERR
        trap 'cleanup_upstream_repository' EXIT
        (
            create_sandbox

            # Create an agent in the upstream repository and install it
            mkdir -p "$DEFAULT_REMOTE_REPOSITORY/agents"
            cat > "$DEFAULT_REMOTE_REPOSITORY/agents/modifiable-agent.md" << 'EOF'
---
name: modifiable-agent
description: Agent that will be modified by user
source: claude-toolkit
---

You are an agent that will be modified by user.

When invoked:
1. Analyze requests
2. Provide helpful responses
3. Maintain professionalism

Focus on delivering accurate information.
EOF
            git -C "$DEFAULT_REMOTE_REPOSITORY" add .
            git -C "$DEFAULT_REMOTE_REPOSITORY" commit -m "Added modifiable agent" >/dev/null 2>&1

            # First installation - this creates snapshot
            assert_command_succeeds "First installation should succeed" -- ./scripts/claude-agents.sh install >/dev/null 2>&1
            assert_file_exists "$HOME/.claude/agents/modifiable-agent.md" "Agent should be installed"

            # User modifies the file
            echo "User added custom instructions" >> "$HOME/.claude/agents/modifiable-agent.md"

            # Get checksum after user modification
            local checksum_after_user_change
            checksum_after_user_change=$(calculate_file_checksum "$HOME/.claude/agents/modifiable-agent.md")

            # Remove the agent from upstream repository
            rm "$DEFAULT_REMOTE_REPOSITORY/agents/modifiable-agent.md"
            git -C "$DEFAULT_REMOTE_REPOSITORY" add .
            git -C "$DEFAULT_REMOTE_REPOSITORY" commit -m "Removed modifiable agent" >/dev/null 2>&1

            # Second installation should fail because file has user changes
            local install_output
            install_output=$(assert_command_fails "Installation should fail with user-modified orphaned file" -- ./scripts/claude-agents.sh install 2>&1)

            assert_contains "orphaned installed file: modifiable-agent.md (contains user changes - use reinstall to force)" "$install_output" "Should detect user-modified orphaned file"
            
            # Verify file is unchanged using checksum
            local checksum_after_failed_install
            checksum_after_failed_install=$(calculate_file_checksum "$HOME/.claude/agents/modifiable-agent.md")
            assert_equals "$checksum_after_user_change" "$checksum_after_failed_install" "User-modified file should remain unchanged after failed install"
        )
    )
}

# Register all test functions
register_tests \
    "test_install" \
    "test_install_adds_new_files" \
    "test_install_fails_on_changed_files" \
    "test_install_succeeds_on_upstream_changes" \
    "test_install_succeeds_on_orphaned_tracked_files" \
    "test_install_preserves_user_agents" \
    "test_install_handles_agent_conflicts" \
    "test_install_error_handling_permission_issues" \
    "test_install_with_source_option" \
    "test_install_dry_run" \
    "test_install_fails_on_orphaned_user_created_files" \
    "test_install_fails_on_orphaned_modified_files"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-agents.sh install functionality" "$@"
fi