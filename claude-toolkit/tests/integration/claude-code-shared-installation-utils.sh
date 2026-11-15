#!/bin/bash
# claude-code-shared-installation-utils.sh - Shared installation utilities for integration tests
# 
# Purpose: Provide shared Claude Code installation optimization for test performance
# Usage: Source this file in test scripts to access shared installation functions
# Approach: Create one real installation, copy to each test sandbox for isolation

# Global variable for shared installation path
SHARED_CLAUDE_INSTALLATION=""

setup_shared_claude_installation() {
    local target_version="${1:-}"

    test_log "INFO" "Setting up shared claude-code installation for tests (may take a minute or two)..."
    
    create_sandbox
    local shared_sandbox_dir="$sandbox_dir"
    
    SHARED_CLAUDE_INSTALLATION="$shared_sandbox_dir"
    
    setup_fake_bash_shell

    if [[ -n "$target_version" ]]; then
        "./scripts/claude-code.sh" install --version "$target_version" >/dev/null 2>&1
    else
        "./scripts/claude-code.sh" install >/dev/null 2>&1
    fi

    if [[ ! -f "$shared_sandbox_dir/.local/bin/claude" ]]; then
        return 1
    fi
    
    if ! "$shared_sandbox_dir/.local/bin/claude" --check-version >/dev/null; then
        return 1
    fi
}

cleanup_shared_claude_installation() {
    if [[ -n "$SHARED_CLAUDE_INSTALLATION" ]] && [[ -d "$SHARED_CLAUDE_INSTALLATION" ]]; then
        cleanup_sandbox "$SHARED_CLAUDE_INSTALLATION"
    fi
}

copy_shared_claude_installation() {
    local target_version="${1:-}"
    local source_installation="$SHARED_CLAUDE_INSTALLATION"
    
    local shared_version
    if [[ -L "$source_installation/.local/share/claude/current" ]]; then
        shared_version=$(readlink "$source_installation/.local/share/claude/current" 2>/dev/null | sed 's|.*versions/||' || echo "")
    fi
    
    if [[ -z "$shared_version" ]]; then
        return 1
    fi
    
    if [[ -z "$target_version" ]]; then
        target_version="$shared_version"
    fi
    
    if [[ ! -f "$sandbox_dir/.local/bin/claude" ]]; then        
        mkdir -p "$sandbox_dir/.local/bin"
        mkdir -p "$sandbox_dir/.local/share/claude"
        
        cp -rP "$source_installation/.local/bin/." "$sandbox_dir/.local/bin/"
        
        cp -rP "$source_installation/.local/share/claude/current" "$sandbox_dir/.local/share/claude/"

        if [[ -d "$source_installation/.local/share/claude/registry-tools" ]]; then
            cp -rP "$source_installation/.local/share/claude/registry-tools" "$sandbox_dir/.local/share/claude/"
        fi

        mkdir -p "$sandbox_dir/.local/share/claude/versions"
        cp -rP "$source_installation/.local/share/claude/versions/$shared_version" "$sandbox_dir/.local/share/claude/versions/$target_version"
        
        if [[ "$target_version" != "$shared_version" ]]; then
            rm -f "$sandbox_dir/.local/share/claude/current"
            ln -sf "versions/$target_version" "$sandbox_dir/.local/share/claude/current"
        fi
    else        
        mkdir -p "$sandbox_dir/.local/share/claude/versions"
        
        cp -rP "$source_installation/.local/share/claude/versions/$shared_version" "$sandbox_dir/.local/share/claude/versions/$target_version"
    fi
    
    if [[ -d "$source_installation/.cache" ]]; then
        cp -rP "$source_installation/.cache" "$sandbox_dir/" 2>/dev/null || true
    fi
    if [[ -f "$source_installation/.bashrc" ]]; then
        cp -rP "$source_installation/.bashrc" "$sandbox_dir/" 2>/dev/null || true
    fi
    if [[ -f "$source_installation/.bash_profile" ]]; then
        cp -rP "$source_installation/.bash_profile" "$sandbox_dir/" 2>/dev/null || true
    fi
    if [[ -d "$source_installation/bin" ]]; then
        cp -rP "$source_installation/bin" "$sandbox_dir/" 2>/dev/null || true
        export PATH="$sandbox_dir/bin:$PATH"
    fi
}
