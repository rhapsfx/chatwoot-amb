#!/bin/bash
# test-claude-agents-list.sh - Tests claude-agents.sh list functionality with multiple sources
# 
# Purpose: Test scripts/claude-agents.sh list functionality according to multiple sources specification
# Dependencies: None (creates own test agent files)
# Approach: Create comprehensive test scenarios for all source types, filtering options, and output formats

source "$(dirname "$0")/../utils/test-harness.sh"

export PORCELAIN=true

test_list_all_sources_default() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/agents"
        
        # Create claude-toolkit source agents
        cat > "$HOME/.claude/agents/toolkit-debugger.md" << 'EOF'
---
name: toolkit-debugger
description: First claude-toolkit agent for debugging issues
source: claude-toolkit
---

You are a debugging specialist from the toolkit.

When invoked:
1. Analyze error messages and stack traces
2. Identify root causes
3. Provide solutions

Focus on systematic debugging approaches.
EOF
        
        cat > "$HOME/.claude/agents/toolkit-reviewer.md" << 'EOF'
---
name: toolkit-reviewer
description: Second claude-toolkit agent for code review
source: claude-toolkit
---

You are a code review specialist from the toolkit.

When invoked:
1. Review code quality
2. Check for security issues
3. Suggest improvements

Focus on maintaining high code standards.
EOF
        
        # Create user agents (no source field)
        cat > "$HOME/.claude/agents/user-helper.md" << 'EOF'
---
name: user-helper
description: First user agent for personal assistance
---

You are a personal assistant agent.

When invoked:
1. Help with daily tasks
2. Provide personalized recommendations
3. Maintain user preferences

Focus on personal productivity.
EOF
        
        # Create team-alpha source agents
        mkdir -p "$HOME/.claude/agents"
        cat > "$HOME/.claude/agents/team-optimizer.md" << 'EOF'
---
name: team-optimizer
description: Team alpha optimization agent
source: team-alpha
---

You are a performance optimization specialist.

When invoked:
1. Analyze performance bottlenecks
2. Suggest optimization strategies
3. Implement performance improvements

Focus on scalable solutions.
EOF
        
        # Test default list (should show all sources)
        local list_output
        list_output=$(assert_command_succeeds "List all sources should succeed" -- ./scripts/claude-agents.sh list)
        
        # Should contain agents from all sources
        assert_contains "toolkit-debugger.md" "$list_output" "Should list claude-toolkit debugger agent"
        assert_contains "toolkit-reviewer.md" "$list_output" "Should list claude-toolkit reviewer agent"
        assert_contains "user-helper.md" "$list_output" "Should list user helper agent"
        assert_contains "team-optimizer.md" "$list_output" "Should list team-alpha optimizer agent"
        
        # Check source indicators
        assert_contains "claude-toolkit" "$list_output" "Should show claude-toolkit source"
        assert_contains "user" "$list_output" "Should show user source"
        assert_contains "team-alpha" "$list_output" "Should show team-alpha source"
    )
}

test_list_source_filtering() {
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
        
        cat > "$HOME/.claude/agents/user-agent.md" << 'EOF'
---
name: user-agent
description: User agent
---

You are a user agent.
EOF
        
        cat > "$HOME/.claude/agents/team-agent.md" << 'EOF'
---
name: team-agent
description: Team agent
source: team-alpha
---

You are a team agent.
EOF
        
        # Test filtering by claude-toolkit source
        local toolkit_output
        toolkit_output=$(assert_command_succeeds "List toolkit source should succeed" -- ./scripts/claude-agents.sh list --source claude-toolkit)
        
        assert_contains "toolkit-agent.md" "$toolkit_output" "Should list toolkit agent"
        assert_not_contains "user-agent.md" "$toolkit_output" "Should not list user agent"
        assert_not_contains "team-agent.md" "$toolkit_output" "Should not list team agent"
        
        # Test filtering by user source
        local user_output
        user_output=$(assert_command_succeeds "List user source should succeed" -- ./scripts/claude-agents.sh list --source user)
        
        assert_not_contains "toolkit-agent.md" "$user_output" "Should not list toolkit agent"
        assert_contains "user-agent.md" "$user_output" "Should list user agent"
        assert_not_contains "team-agent.md" "$user_output" "Should not list team agent"
        
        # Test filtering by team-alpha source
        local team_output
        team_output=$(assert_command_succeeds "List team source should succeed" -- ./scripts/claude-agents.sh list --source team-alpha)
        
        assert_not_contains "toolkit-agent.md" "$team_output" "Should not list toolkit agent"
        assert_not_contains "user-agent.md" "$team_output" "Should not list user agent"
        assert_contains "team-agent.md" "$team_output" "Should list team agent"
    )
}

test_list_multiple_sources() {
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
        
        cat > "$HOME/.claude/agents/user-agent.md" << 'EOF'
---
name: user-agent
description: User agent
---

You are a user agent.
EOF
        
        cat > "$HOME/.claude/agents/team-agent.md" << 'EOF'
---
name: team-agent
description: Team agent
source: team-alpha
---

You are a team agent.
EOF
        
        # Test filtering by multiple sources
        local multi_output
        multi_output=$(assert_command_succeeds "List multiple sources should succeed" -- ./scripts/claude-agents.sh list --source claude-toolkit,team-alpha)
        
        assert_contains "toolkit-agent.md" "$multi_output" "Should list toolkit agent"
        assert_not_contains "user-agent.md" "$multi_output" "Should not list user agent"
        assert_contains "team-agent.md" "$multi_output" "Should list team agent"
    )
}

test_list_output_formats() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/agents"
        
        cat > "$HOME/.claude/agents/test-agent.md" << 'EOF'
---
name: test-agent
description: A test agent for format checking
source: claude-toolkit
---

You are a test agent for validating output formats.
EOF
        
        # Test compact format (default)
        local compact_output
        compact_output=$(assert_command_succeeds "Compact format should succeed" -- ./scripts/claude-agents.sh list --format compact)
        
        assert_contains "test-agent.md" "$compact_output" "Should show agent filename in compact format"
        assert_contains "claude-toolkit" "$compact_output" "Should show source in compact format"
        
        # Test detailed format
        local detailed_output
        detailed_output=$(assert_command_succeeds "Detailed format should succeed" -- ./scripts/claude-agents.sh list --format detailed)
        
        assert_contains "test-agent.md" "$detailed_output" "Should show agent filename in detailed format"
        assert_contains "A test agent for format checking" "$detailed_output" "Should show description in detailed format"
        assert_contains "claude-toolkit" "$detailed_output" "Should show source in detailed format"
    )
}

test_list_empty_directory_non_porcelain() {
    (
        create_sandbox
        export PORCELAIN=false
        
        # Test list with no agents directory in non-porcelain mode
        local empty_output
        empty_output=$(assert_command_succeeds "List empty directory should succeed (non-porcelain)" -- ./scripts/claude-agents.sh list 2>&1)
        
        # Should not contain "Found" messages when no files exist
        assert_not_contains "Found" "$empty_output" "Should not show 'Found' message when no agents directory exists in non-porcelain mode"
        
        # Test list with empty agents directory in non-porcelain mode
        mkdir -p "$HOME/.claude/agents"
        
        local empty_dir_output
        empty_dir_output=$(assert_command_succeeds "List empty agents directory should succeed (non-porcelain)" -- ./scripts/claude-agents.sh list 2>&1)
        
        assert_not_contains "Found" "$empty_dir_output" "Should not show 'Found' message when agents directory is empty in non-porcelain mode"
        
        # Test nonexistent source in non-porcelain mode
        local nonexistent_output
        nonexistent_output=$(assert_command_succeeds "Nonexistent source should succeed (non-porcelain)" -- ./scripts/claude-agents.sh list --source asdfasdf 2>&1)
        assert_not_contains "Found" "$nonexistent_output" \
            "Should not show 'Found' message for nonexistent source in non-porcelain mode"
    )
}

test_list_empty_directory() {
    (
        create_sandbox
        
        # Test list with no agents directory
        local empty_output
        empty_output=$(assert_command_succeeds "List empty directory should succeed" -- ./scripts/claude-agents.sh list)
        
        # In porcelain mode, empty environment should produce no output
        assert_equals "" "$empty_output" "Should produce empty output when no agents directory exists"
        
        # Test list with empty agents directory
        mkdir -p "$HOME/.claude/agents"
        
        local empty_dir_output
        empty_dir_output=$(assert_command_succeeds "List empty agents directory should succeed" -- ./scripts/claude-agents.sh list)
        
        assert_equals "" "$empty_dir_output" "Should produce empty output when agents directory is empty"
    )
}

test_list_with_nonexistent_source() {
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
        
        # Test filtering by nonexistent source
        local nonexistent_output
        nonexistent_output=$(assert_command_succeeds "List nonexistent source should succeed" -- ./scripts/claude-agents.sh list --source nonexistent-source)
        
        # In porcelain mode, should produce empty output for nonexistent source
        assert_equals "" "$nonexistent_output" "Should produce empty output for nonexistent source"
        assert_not_contains "toolkit-agent.md" "$nonexistent_output" "Should not list agents from other sources"
    )
}

test_list_dry_run() {
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
        
        # Test dry run mode
        local dry_run_output
        dry_run_output=$(assert_command_succeeds "List dry run should succeed" -- ./scripts/claude-agents.sh list --dry-run 2>&1)
        
        assert_contains "dryrun:" "$dry_run_output" "Should show dry run markers"
    )
}

test_list_porcelain_output() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/agents"
        
        cat > "$HOME/.claude/agents/test-agent.md" << 'EOF'
---
name: test-agent
description: Test agent for porcelain output
source: claude-toolkit
---

You are a test agent.
EOF
        
        # Test porcelain output format
        local porcelain_output
        porcelain_output=$(assert_command_succeeds "Porcelain output should succeed" -- ./scripts/claude-agents.sh list --porcelain)
        
        # Porcelain output should be tab-separated with specific format
        assert_contains "test-agent.md" "$porcelain_output" "Should show agent filename in porcelain format"
        assert_contains "claude-toolkit" "$porcelain_output" "Should show source in porcelain format"
        
        # Should not contain user-friendly messages
        assert_not_contains "Found" "$porcelain_output" "Should not contain user messages in porcelain mode"
    )
}

test_list_agents_with_complex_descriptions() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/agents"
        
        cat > "$HOME/.claude/agents/complex-agent.md" << 'EOF'
---
name: complex-agent
description: Agent with "quotes" and special characters & symbols
source: claude-toolkit
---

You are a complex agent with special characters in your description.
EOF
        
        # Test that complex descriptions are handled properly
        local complex_output
        complex_output=$(assert_command_succeeds "Complex descriptions should be handled" -- ./scripts/claude-agents.sh list --format detailed)
        
        assert_contains "complex-agent.md" "$complex_output" "Should show agent with complex description"
        assert_contains "quotes" "$complex_output" "Should handle quotes in description"
        assert_contains "special characters" "$complex_output" "Should handle special characters"
    )
}

# Register all test functions
register_tests \
    "test_list_all_sources_default" \
    "test_list_source_filtering" \
    "test_list_multiple_sources" \
    "test_list_output_formats" \
    "test_list_empty_directory" \
    "test_list_empty_directory_non_porcelain" \
    "test_list_with_nonexistent_source" \
    "test_list_dry_run" \
    "test_list_porcelain_output" \
    "test_list_agents_with_complex_descriptions"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-agents.sh list functionality" "$@"
fi