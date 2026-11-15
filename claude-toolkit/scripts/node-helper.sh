#!/bin/bash

# Node.js Helper Functions
# This script provides reusable Node.js and npm registry management functions for Claude Toolkit scripts.

# Symlink-safe way to get this script's real directory
script_dir="$(
  src="${BASH_SOURCE[0]}"
  while [ -h "$src" ]; do # follow symlinks
    dir="$(cd -P -- "$(dirname -- "$src")" && pwd)"
    src="$(readlink -- "$src")"
    [[ "$src" = /* ]] || src="$dir/$src"
  done
  cd -P -- "$(dirname -- "$src")" && pwd
)"

source "$script_dir/jq-helper.sh"

# Configuration
CORPORATE_NPM_REGISTRY="${CORPORATE_NPM_REGISTRY:-https://npm.apple.com/}"
CLAUDE_PACKAGE="${CLAUDE_PACKAGE:-@apple/claude-code}"
CORPORATE_NODE_DISTRIBUTIONS_URL="${CORPORATE_NODE_DISTRIBUTIONS_URL:-https://artifacts.apple.com/node-distributions}"

# get_corporate_npm_registry - Returns corporate npm registry URL
get_corporate_npm_registry() {
    printf '%s' "$CORPORATE_NPM_REGISTRY"
}

# get_claude_package - Returns Claude Code npm package name
get_claude_package() {
    printf '%s' "$CLAUDE_PACKAGE"
}

# get_corporate_node_distributions_url - Returns corporate Node.js distribution URL
get_corporate_node_distributions_url() {
    printf '%s' "$CORPORATE_NODE_DISTRIBUTIONS_URL"
}

# Centralized Node.js archive download with caching
download_nodejs_archive() {
    local target_dir="${1:-}"
    local nodejs_version="${2:-}"
    local cache_dir="$3"

    log_debug "download_nodejs_archive(~${target_dir/#$HOME}, $nodejs_version)"

    # Determine platform and architecture
    local platform arch
    platform="$(get_platform)"
    arch="$(get_architecture)"

    local node_package="node-v${nodejs_version}-${platform}-${arch}.tar.gz"
    local download_url
    download_url="$(get_corporate_node_distributions_url)/v${nodejs_version}/${node_package}"
    local cache_path="$cache_dir/nodejs-archives"
    local cached_archive="$cache_path/$node_package"

    # Create cache directory
    mkdir -p "$cache_path"

    # Check if archive exists in cache and is valid
    if [[ -f "$cached_archive" ]]; then
        log_debug "download_nodejs_archive: Using cached Node.js archive: ~${cached_archive/#$HOME}"
        # Verify archive integrity (basic check)
        if tar -tzf "$cached_archive" >/dev/null 2>&1; then
            # Copy from cache to target directory
            cp "$cached_archive" "$target_dir/$node_package"
            return 0
        else
            log_debug "download_nodejs_archive: Cached archive is corrupted, re-downloading..."
            rm -f "$cached_archive"
        fi
    fi

    # Download to cache first
    log_debug "download_nodejs_archive: Downloading Node.js archive to cache: $download_url"
    if [[ "$DEBUG" == true ]]; then
        if ! curl -L -o "$cached_archive" "$download_url"; then
            log_error "Failed to download Node.js from $download_url"
            return 1
        fi
    else
        if ! curl -L -so "$cached_archive" "$download_url"; then
            log_error "Failed to download Node.js from $download_url"
            return 1
        fi
    fi

    # Verify downloaded archive
    if ! tar -tzf "$cached_archive" >/dev/null 2>&1; then
        log_error "Downloaded Node.js archive is corrupted"
        rm -f "$cached_archive"
        return 1
    fi

    # Copy from cache to target directory
    cp "$cached_archive" "$target_dir/$node_package"
    log_debug "download_nodejs_archive: Node.js archive cached and copied to target directory"

    log_debug "download_nodejs_archive: OK"
    return 0
}

install_nodejs() {
    local target_dir="${1:-}"
    local nodejs_version="${2:-}"
    local cache_dir="$3"

    log_debug "install_nodejs(~${target_dir/#$HOME}, $nodejs_version)"
    log_info "Installing Node.js $nodejs_version..."

    mkdir -p "$target_dir"

    # Run directory-changing operations in subshell (auto-restores on exit)
    (
        cd "$target_dir" || exit 1

        # Remove existing Node.js installation in this version if present
        if [[ -d "nodejs" ]]; then
            rm -rf "nodejs"
        fi

        # Determine platform and architecture for package name
        local platform arch
        platform="$(get_platform)"
        arch="$(get_architecture)"

        local node_package="node-v${nodejs_version}-${platform}-${arch}.tar.gz"

        # Use centralized download function
        if ! download_nodejs_archive "$(pwd)" "$nodejs_version" "$cache_dir"; then
            log_error "Failed to download Node.js from $(get_corporate_node_distributions_url)"
            exit 1
        fi

        # Extract and rename (with permission fixes for Docker containers)
        tar -xzf "$node_package" --no-same-owner --no-same-permissions
        chmod -R u+rwX "node-v${nodejs_version}-${platform}-${arch}"
        mv -f "node-v${nodejs_version}-${platform}-${arch}" nodejs
        rm "$node_package"

        # Verify installation
        local nodejs_dir="$target_dir/nodejs"

        if [[ ! -f "$nodejs_dir/bin/node" ]]; then
            log_error "Node.js installation failed - binary not found in $nodejs_dir/bin/node"
            exit 1
        fi

        # Directory automatically restored on subshell exit
    ) || return $?  # Propagate any failures from subshell

    log_success "Installed Node.js $nodejs_version"
    log_debug "install_nodejs: OK"
}

# configure_npm_rc - Creates .npmrc file with corporate registry configuration
configure_npm_rc() {
    local target_dir=${1:-}
    local cache_dir="$2"

    log_debug "configure_npm_rc(~${target_dir/#$HOME})"

    local npm_rc_file="$target_dir/.npmrc"

    cat > "$npm_rc_file" << EOF
registry=$(get_corporate_npm_registry)
cache=$cache_dir
EOF
    log_debug "configure_npm_rc: OK"
}

# Query npm registry for latest version using dedicated tools
query_latest_claude_package_version() {
    local registry_tools_dir="$1"

    (
        cd "$registry_tools_dir" || exit 1

        export PATH="$registry_tools_dir/nodejs/bin:$PATH"

        # Query for latest version
        local latest_version
        if latest_version=$(npm view "$(get_claude_package)" version --registry="$(get_corporate_npm_registry)" 2>/dev/null); then
            echo "$latest_version"
        else
            return 1
        fi
    ) || return 1
}

# Query npm registry for all available versions using dedicated tools
query_available_claude_package_versions() {
    local registry_tools_dir="$1"

    local nodejs_bin_dir="$registry_tools_dir/nodejs/bin"

    # Get jq binary (global or cached)
    local jq_binary
    if ! jq_binary=$(get_jq_binary); then
        log_error "Failed to obtain jq binary for JSON parsing"
        return 1
    fi

    # Run query in registry tools directory
    (
        cd "$registry_tools_dir" || return 1

        export PATH="$nodejs_bin_dir:$PATH"

        # Query for all versions and sort them
        local available_versions
        if available_versions=$(npm view "$(get_claude_package)" versions --json --registry="$(get_corporate_npm_registry)" 2>&1); then
            # Parse JSON array and sort using sort -V
            echo "$available_versions" | "$jq_binary" -r '.[]' | sort -V
        else
            return 1
        fi
    ) || return 1
}

# Install Claude Code from corporate registry to version-specific directory
install_claude_code_npm_package() {
    local target_version="$1"
    local target_dir="$2"
    log_debug "install_claude_code_npm_package($target_version)"

    local package_spec="${CLAUDE_PACKAGE}@${target_version}"

    log_info "Installing Claude Code package $package_spec"

    log_debug "install_claude_code_npm_package: package_spec=$package_spec"

    # Run directory-changing operations in subshell (auto-restores on exit)
    (
        cd "$target_dir" || exit 1

        local nodejs_dir="$target_dir/nodejs"
        export PATH="$nodejs_dir/bin:$PATH"

        if [[ "$DEBUG" == true ]]; then
            if ! npm install -g "$package_spec" --prefix="$nodejs_dir" --registry="$(get_corporate_npm_registry)"; then
                log_error "Failed to install $package_spec"
                log_error "Ensure you have access to the corporate registry and the package exists"
                exit 1
            fi
        else
            if ! npm install -g "$package_spec" --prefix="$nodejs_dir" --registry="$(get_corporate_npm_registry)" >/dev/null 2>&1; then
                log_error "Failed to install $package_spec"
                log_error "Ensure you have access to the corporate registry and the package exists"
                exit 1
            fi
        fi

        # Fix quirky post-installation layout of claude-code packages (probably caused by --prefix argument)
        if [[ -d "$nodejs_dir/lib/node_modules/@apple/claude-code/node_modules" ]] && [[ ! -d "$nodejs_dir/lib/node_modules/@apple/claude-code/packages/cli/node_modules" ]]; then
            mkdir -p "$nodejs_dir/lib/node_modules/@apple/claude-code/packages/cli"
            ln -s "$nodejs_dir/lib/node_modules/@apple/claude-code/node_modules" \
                  "$nodejs_dir/lib/node_modules/@apple/claude-code/packages/cli/node_modules"
        fi

        # Directory automatically restored on subshell exit
    ) || return $?  # Propagate any failures from subshell

    log_success "Installed Claude Code package $package_spec"
    log_debug "install_claude_code_npm_package: OK"
}
