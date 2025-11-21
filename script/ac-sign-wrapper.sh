#!/bin/bash
#
# Conditional Git Signing Wrapper for ac-sign
# 
# This script wraps the Apple Code Signing tool (ac-sign) to conditionally
# sign git commits based on the remote repository domain.
#
# Behavior:
# - For repositories with apple.com remotes: Uses ac-sign for signing
# - For all other repositories (including GitHub): Bypasses signing
#
# Installation:
# 1. Backup original: sudo mv /usr/local/bin/ac-sign /usr/local/bin/ac-sign-original
# 2. Copy this script: sudo cp script/ac-sign-wrapper.sh /usr/local/bin/ac-sign
# 3. Make executable: sudo chmod +x /usr/local/bin/ac-sign

# Path to the original ac-sign binary
ORIGINAL_AC_SIGN="/usr/local/bin/ac-sign-original"

# Debug log file (optional, comment out for production)
# DEBUG_LOG="/tmp/ac-sign-wrapper.log"

# Function to log debug messages
debug_log() {
    if [ -n "$DEBUG_LOG" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$DEBUG_LOG"
    fi
}

# Function to check if any git remote contains apple.com
is_apple_repository() {
    debug_log "Checking if repository is Apple domain..."
    
    # Try multiple methods to find the git repository
    local git_dir=""
    local repo_root=""
    
    # Method 1: Use GIT_DIR environment variable (set by git during operations)
    if [ -n "$GIT_DIR" ]; then
        git_dir="$GIT_DIR"
        debug_log "Found GIT_DIR: $git_dir"
    fi
    
    # Method 2: Try current directory
    if [ -z "$git_dir" ]; then
        git_dir=$(git rev-parse --git-dir 2>/dev/null)
        debug_log "git rev-parse --git-dir: $git_dir"
    fi
    
    # Method 3: Try from PWD
    if [ -z "$git_dir" ] && [ -n "$PWD" ]; then
        git_dir=$(cd "$PWD" 2>/dev/null && git rev-parse --git-dir 2>/dev/null)
        debug_log "From PWD: $git_dir"
    fi
    
    # If we still can't find a git directory, default to not signing
    if [ -z "$git_dir" ] || [ ! -d "$git_dir" ]; then
        debug_log "No git directory found, defaulting to no signing"
        return 1
    fi
    
    # Get the repository root
    if [[ "$git_dir" == /* ]]; then
        # Absolute path
        repo_root=$(dirname "$git_dir")
        if [ "$git_dir" = "$repo_root/.git" ]; then
            repo_root=$(dirname "$git_dir")
        fi
    else
        # Relative path
        repo_root=$(cd "$(dirname "$git_dir")" 2>/dev/null && pwd)
    fi
    
    debug_log "Repository root: $repo_root"
    
    if [ -z "$repo_root" ] || [ ! -d "$repo_root" ]; then
        debug_log "Could not determine repository root, defaulting to no signing"
        return 1
    fi
    
    # Get all remote URLs from the repository
    local remotes
    remotes=$(git -C "$repo_root" remote -v 2>/dev/null | awk '{print $2}' | sort -u)
    
    debug_log "Remotes found:"
    debug_log "$remotes"
    
    # Check if any remote contains apple.com
    if echo "$remotes" | grep -q "apple\.com"; then
        debug_log "Apple repository detected - will sign"
        return 0  # Is an Apple repository
    else
        debug_log "Non-Apple repository detected - will NOT sign"
        return 1  # Not an Apple repository
    fi
}

# Main logic
debug_log "=== ac-sign wrapper called ==="
debug_log "Arguments: $*"
debug_log "PWD: $PWD"
debug_log "GIT_DIR: $GIT_DIR"

if is_apple_repository; then
    # This is an Apple repository - use the original ac-sign
    debug_log "Calling original ac-sign"
    if [ -x "$ORIGINAL_AC_SIGN" ]; then
        exec "$ORIGINAL_AC_SIGN" "$@"
    else
        echo "Error: Original ac-sign binary not found at $ORIGINAL_AC_SIGN" >&2
        exit 1
    fi
else
    # Not an Apple repository - bypass signing
    debug_log "Bypassing signing for non-Apple repository"
    
    # Check if this is a signing operation (typically has -bsau flag)
    if [[ "$*" == *"-bsau"* ]] || [[ "$*" == *"--sign"* ]]; then
        debug_log "Signing operation detected, returning success without signing"
        
        # Read input if provided via stdin
        if [ ! -t 0 ]; then
            cat > /dev/null
        fi
        
        # Return success without actually signing
        # Git will proceed without a signature
        exit 0
    else
        # For other operations (like --version), pass through to original
        debug_log "Non-signing operation, passing to original ac-sign"
        if [ -x "$ORIGINAL_AC_SIGN" ]; then
            exec "$ORIGINAL_AC_SIGN" "$@"
        else
            exit 0
        fi
    fi
fi