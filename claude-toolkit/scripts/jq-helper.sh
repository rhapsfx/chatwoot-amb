#!/bin/bash

# jq Helper Functions
# This script provides reusable jq binary management functions for Claude Toolkit scripts.

# Configuration
JQ_VERSION="${JQ_VERSION:-1.8.1}"
JQ_BASE_URL="${JQ_BASE_URL:-https://artifacts.apple.com/github-releases/jqlang/jq/releases/download/}"

# get_jq_version - Returns jq version to use for JSON parsing
get_jq_version() {
    printf '%s' "$JQ_VERSION"
}

# get_jq_base_url - Returns base URL for jq binary downloads
get_jq_base_url() {
    printf '%s' "$JQ_BASE_URL"
}

# Get or download jq binary for JSON parsing
get_jq_binary() {
    # Check if jq is globally available AND functional
    local command_output
    if command_output=$(command -v jq) && "$command_output" --version >/dev/null 2>&1; then
        echo "$command_output"
        return 0
    fi

    # Determine platform and architecture for jq binary
    local platform arch jq_binary
    platform="$(get_platform)"
    arch="$(get_architecture)"
    
    case "$platform" in
        darwin)
            case "$arch" in
                arm64) jq_binary="jq-macos-arm64" ;;
                x64) jq_binary="jq-macos-amd64" ;;
                *) 
                    log_error "Unsupported macOS architecture: $arch"
                    return 1
                    ;;
            esac
            ;;
        linux)
            case "$arch" in
                arm64) jq_binary="jq-linux-arm64" ;;
                x64) jq_binary="jq-linux-amd64" ;;
                *) 
                    log_error "Unsupported Linux architecture: $arch"
                    return 1
                    ;;
            esac
            ;;
        *)
            log_error "Unsupported platform for jq: $platform"
            return 1
            ;;
    esac

    local jq_url
    jq_url="$(get_jq_base_url)/jq-$(get_jq_version)/${jq_binary}"
    local jq_cache_dir
    jq_cache_dir="$(get_claude_cache_dir)/jq/$(get_jq_version)"
    local cached_jq="$jq_cache_dir/jq"

    # Create cache directory
    mkdir -p "$jq_cache_dir"

    # Check if cached jq exists and is executable
    if [[ -f "$cached_jq" ]] && [[ -x "$cached_jq" ]]; then
        echo "$cached_jq"
        return 0
    fi

    # Download jq binary
    if [[ "$DEBUG" == true ]]; then
        if ! curl -L -o "$cached_jq" "$jq_url"; then
            log_error "Failed to download jq from $jq_url" >&2
            return 1
        fi
    else
        if ! curl -L -so "$cached_jq" "$jq_url"; then
            log_error "Failed to download jq from $jq_url" >&2
            return 1
        fi
    fi
    
    # Make executable
    if ! chmod +x "$cached_jq"; then
        log_error "Failed to make jq binary executable" >&2
        return 1
    fi
    
    # Verify the binary works
    if ! "$cached_jq" --version >/dev/null 2>&1; then
        log_error "Downloaded jq binary is not functional" >&2
        rm -f "$cached_jq"
        return 1
    fi
    
    echo "$cached_jq"
}