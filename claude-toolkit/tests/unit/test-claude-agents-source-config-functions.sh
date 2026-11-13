#!/bin/bash
# test-claude-agents-source-config-functions.sh - Tests source configuration functions for claude-agents
# 
# Purpose: Test the source configuration functions when used with agents template type
# Dependencies: None (sources template-management.sh directly)

source "$(dirname "$0")/../utils/test-harness.sh"

# Source the template management library to get access to functions under test
source "$(dirname "$0")/../../scripts/template-management.sh"

export DEBUG=true

test_get_template_install_dir_agents() {
    local install_dir
    install_dir=$(get_template_install_dir "$TEMPLATE_TYPE_AGENTS")
    
    local expected_dir="$HOME/.claude/agents"
    assert_equals "$expected_dir" "$install_dir" "Should return correct agents install directory"
}

test_get_template_source_subdirectory_agents() {
    local subdirectory
    subdirectory=$(get_template_source_subdirectory "$TEMPLATE_TYPE_AGENTS")
    
    assert_equals "agents" "$subdirectory" "Should return correct agents subdirectory"
}

test_template_type_constants() {
    assert_equals "commands" "$TEMPLATE_TYPE_COMMANDS" "Commands template type should be correct"
    assert_equals "agents" "$TEMPLATE_TYPE_AGENTS" "Agents template type should be correct"
}

test_get_template_files_agents() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/agents"
        
        # Create test agent files
        cat > "$HOME/.claude/agents/test-agent-1.md" << 'EOF'
---
name: test-agent-1
description: Test agent 1
---

You are test agent 1.
EOF
        
        cat > "$HOME/.claude/agents/test-agent-2.md" << 'EOF'
---
name: test-agent-2
description: Test agent 2
source: claude-toolkit
---

You are test agent 2.
EOF
        
        # Create non-agent file (should be ignored)
        echo "not an agent" > "$HOME/.claude/agents/readme.txt"
        
        local agent_files
        agent_files=$(get_template_files "$HOME/.claude/agents")
        
        assert_contains "test-agent-1.md" "$agent_files" "Should find first agent file"
        assert_contains "test-agent-2.md" "$agent_files" "Should find second agent file"
        assert_not_contains "readme.txt" "$agent_files" "Should ignore non-markdown files"
        
        # Count the files
        local file_count
        file_count=$(echo "$agent_files" | wc -l | tr -d ' ')
        assert_equals "2" "$file_count" "Should find exactly 2 agent files"
    )
}

test_get_template_file_source_agents() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/agents"
        
        # Create agent with explicit source
        cat > "$HOME/.claude/agents/toolkit-agent.md" << 'EOF'
---
name: toolkit-agent
description: Toolkit agent
source: claude-toolkit
---

You are a toolkit agent.
EOF
        
        # Create agent without source (should default to user)
        cat > "$HOME/.claude/agents/user-agent.md" << 'EOF'
---
name: user-agent
description: User agent
---

You are a user agent.
EOF
        
        local toolkit_source
        toolkit_source=$(get_template_file_source "$HOME/.claude/agents/toolkit-agent.md")
        assert_equals "claude-toolkit" "$toolkit_source" "Should extract explicit source"
        
        local user_source
        user_source=$(get_template_file_source "$HOME/.claude/agents/user-agent.md")
        assert_equals "user" "$user_source" "Should default to user for missing source"
    )
}

test_filter_template_files_by_source_agents() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/agents"
        
        # Create agents with different sources
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
        
        local all_agents
        all_agents=$(get_template_files "$HOME/.claude/agents")
        
        # Test filtering by claude-toolkit source
        local toolkit_agents
        toolkit_agents=$(echo "$all_agents" | filter_template_files_by_source "claude-toolkit")
        
        assert_contains "toolkit-agent.md" "$toolkit_agents" "Should include toolkit agent"
        assert_not_contains "team-agent.md" "$toolkit_agents" "Should exclude team agent"
        assert_not_contains "user-agent.md" "$toolkit_agents" "Should exclude user agent"
        
        # Test filtering by user source
        local user_agents
        user_agents=$(echo "$all_agents" | filter_template_files_by_source "user")
        
        assert_not_contains "toolkit-agent.md" "$user_agents" "Should exclude toolkit agent"
        assert_not_contains "team-agent.md" "$user_agents" "Should exclude team agent"
        assert_contains "user-agent.md" "$user_agents" "Should include user agent"
        
        # Test filtering by all sources
        local all_filtered
        all_filtered=$(echo "$all_agents" | filter_template_files_by_source "all")
        
        assert_contains "toolkit-agent.md" "$all_filtered" "Should include toolkit agent for all"
        assert_contains "team-agent.md" "$all_filtered" "Should include team agent for all"
        assert_contains "user-agent.md" "$all_filtered" "Should include user agent for all"
        
        # Test filtering by comma-separated sources
        local multi_agents
        multi_agents=$(echo "$all_agents" | filter_template_files_by_source "claude-toolkit,team-alpha")
        
        assert_contains "toolkit-agent.md" "$multi_agents" "Should include toolkit agent for multi"
        assert_contains "team-agent.md" "$multi_agents" "Should include team agent for multi"
        assert_not_contains "user-agent.md" "$multi_agents" "Should exclude user agent for multi"
    )
}

test_generate_stable_template_file_name_agents() {
    local stable_name
    stable_name=$(generate_stable_template_file_name "debugger.md" "claude-toolkit")
    
    assert_equals "debugger-claude-toolkit.md" "$stable_name" "Should generate stable name for agent"
    
    # Test with agent that already has source suffix
    local already_stable
    already_stable=$(generate_stable_template_file_name "reviewer-team-alpha.md" "team-beta")
    
    assert_equals "reviewer-team-alpha-team-beta.md" "$already_stable" "Should append source even if already present"
}

test_emit_template_file_info_agents() {
    (
        create_sandbox
        
        mkdir -p "$HOME/.claude/agents"
        
        cat > "$HOME/.claude/agents/info-agent.md" << 'EOF'
---
name: info-agent
description: Agent with detailed information for testing
source: claude-toolkit
---

You are an agent used for testing file info emission.
EOF
        
        local file_info
        file_info=$(echo "$HOME/.claude/agents/info-agent.md" | emit_template_file_info)
        
        assert_contains "info-agent.md" "$file_info" "Should include filename"
        assert_contains "claude-toolkit" "$file_info" "Should include source"
        assert_contains "Agent with detailed information for testing" "$file_info" "Should include description"
        
        # Check tab-separated format
        local field_count
        field_count=$(echo "$file_info" | awk -F'\t' '{print NF}')
        assert_equals "6" "$field_count" "Should have 6 tab-separated fields"
    )
}

register_tests \
    "test_get_template_install_dir_agents" \
    "test_get_template_source_subdirectory_agents" \
    "test_template_type_constants" \
    "test_get_template_files_agents" \
    "test_get_template_file_source_agents" \
    "test_filter_template_files_by_source_agents" \
    "test_generate_stable_template_file_name_agents" \
    "test_emit_template_file_info_agents"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-agents.sh source configuration functions" "$@"
fi