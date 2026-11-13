#!/bin/bash
# upstream-repo-utils.sh - Utilities for managing upstream repository in tests
#
# Purpose: Provides functions to set up and clean up upstream repository copies
#          for testing installation workflows that require a remote repository
# Dependencies: sandbox-utils.sh (for create_sandbox and cleanup_sandbox)
# Usage: Source this file in test scripts that need upstream repository simulation

# Ensure sandbox-utils.sh is loaded
if ! command -v create_sandbox >/dev/null 2>&1; then
    script_dir=$(dirname "${BASH_SOURCE[0]}")
    source "$script_dir/sandbox-utils.sh"
fi

# Set up upstream repository within each test
# Creates a copy of the current repository in a sandbox for use as a "remote" repository
setup_upstream_repository() {
    create_sandbox false

    local script_root_dir
    script_root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

    # Create upstream repository by copying current repository
    cp -r "$script_root_dir" "$sandbox_dir/upstream-repo"

    # Initialize git in upstream repo if needed and commit any changes
    local current_dir=$(pwd)
    cd "$sandbox_dir/upstream-repo"

    # Ensure it's a valid git repository
    if [[ ! -d ".git" ]]; then
        git init
        git add .
        git config user.email "test@example.com"
        git config user.name "Test User"
        git commit -m "Initial commit" >/dev/null 2>&1
    else
        # Commit any uncommitted changes that may be needed by installation
        git add . || true
        git config user.email "test@example.com" || true
        git config user.name "Test User" || true
        git commit -m "Test setup commit" >/dev/null 2>&1 || true
    fi

    # Return to original directory
    cd "$current_dir"

    # Export the upstream repository path for scripts to use
    # Set both SSH and HTTPS defaults to the same local repository
    export DEFAULT_REMOTE_REPOSITORY="$sandbox_dir/upstream-repo"
    export DEFAULT_REMOTE_REPOSITORY_HTTPS="$sandbox_dir/upstream-repo"

    export upstream_repo_sandbox_dir="$sandbox_dir"
}

# Clean up upstream repository sandbox
cleanup_upstream_repository() {
    cleanup_sandbox "$upstream_repo_sandbox_dir"
}
