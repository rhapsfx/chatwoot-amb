#!/bin/bash

# Claude Code Installation Script for macOS and Linux (Enhanced Multi-Shell Support)
# This script installs Claude Code with complete isolation following XDG Base Directory specification
# Requirements: macOS 10.15+ or Linux with glibc 2.17+, internet connection
# Supports: bash, zsh, fish shells with automatic detection and configuration

set -euo pipefail  # Exit on error, undefined vars, pipe failures
export IFS=$' \t\n'  # Explicit IFS setting
export LC_ALL=C       # Deterministic byte-wise sort/grep/collation

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

# Symlink-safe way to get this script's real absolute path (directory + filename)
current_script_file="$(
  src="${BASH_SOURCE[0]}"
  dir="$(cd -P -- "$(dirname -- "$src")" && pwd)"
  while [ -L "$src" ]; do
    target="$(readlink -- "$src")"
    if [[ "$target" = /* ]]; then
      src="$target"
    else
      src="$dir/$target"
    fi
    dir="$(cd -P -- "$(dirname -- "$src")" && pwd)"
  done
  printf '%s/%s\n' "$dir" "$(basename -- "$src")"
)"

# Symlink-safe way to get this script's real filename only (without directory)
current_script_name="${current_script_file##*/}"

source "$script_dir/library.sh"
source "$script_dir/node-helper.sh"

# Configuration
NODEJS_VERSION="${NODEJS_VERSION:-22.17.1}"

# get_claude_cache_dir - Returns Claude cache directory (~/.cache/claude)
get_claude_cache_dir() {
  printf '%s' "$(get_xdg_cache_home)/claude"
}

# get_claude_data_dir - Returns Claude data directory (~/.local/share/claude)
get_claude_data_dir() {
    printf '%s' "$(get_xdg_data_home)/claude"
}

# get_claude_versions_dir - Returns versions directory (data_dir/versions)
get_claude_versions_dir() {
    printf '%s' "$(get_claude_data_dir)/versions"
}

# get_claude_registry_tools_dir - Returns registry tools directory (data_dir/registry-tools)
get_claude_registry_tools_dir() {
    printf '%s' "$(get_claude_data_dir)/registry-tools"
}

# Configuration getter functions for better encapsulation

# get_script_name - Returns script name for config blocks (overridden)
get_script_name() {
    printf '%s' "$current_script_name"
}

# get_claude_current_dir - Returns current version symlink path (data_dir/current)
get_claude_current_dir() {
    printf '%s' "$(get_claude_data_dir)/current"
}

# get_installed_versions - Lists installed version directory names
get_installed_versions() {
    local claude_versions_dir
    claude_versions_dir="$(get_claude_versions_dir)"
    if [[ -d "$claude_versions_dir" ]]; then
        find "$claude_versions_dir" \
            -mindepth 1 -maxdepth 1 -type d \
            ! -name '.*' \
            2>/dev/null | while IFS= read -r path; do
                basename "$path"
            done
    fi
}

# get_installed_versions_count - Returns count of installed versions
get_installed_versions_count() {
    get_installed_versions | wc -l | tr -d ' '
}

# get_latest_installed_version - Returns highest semantic version (fails if none installed)
get_latest_installed_version() {
    local latest
    latest="$(get_installed_versions | /usr/bin/sort -V -r | head -n1)"

    if [[ -z "$latest" ]]; then
        log_error 'Error: no installed versions found.'
        return 1
    fi

    printf '%s' "$latest"
}

# version_is_installed - Tests if version directory exists (exit 0=installed, 1=not)
version_is_installed() {
    local version="$1"
    [[ -d "$(get_claude_versions_dir)/$version" ]]
}

# get_current_version - Returns active version from current symlink (fails if no symlink/broken)
get_current_version() {
    local current_symlink target
    current_symlink="$(get_claude_current_dir)"

    if [[ -L "$current_symlink" ]]; then
        target=$(readlink "$current_symlink" 2>/dev/null) || return 1
        [[ -n "$target" ]] || return 1
        # Check if the symlink destination actually exists
        if [[ ! -d "$current_symlink" ]]; then
            return 1
        fi
        # Strip up to and including 'versions/' — handles absolute and relative targets.
        printf '%s' "${target#*versions/}"
        return 0
    fi

    return 1
}

# is_current_version - Tests if version is currently active (exit 0=current, 1=not)
is_current_version() {
    [[ $(get_current_version) == "$1" ]]
}

# annotate_versions - Reads versions from stdin, outputs "version<TAB>status" (status: "", "installed", "installed,current")
annotate_versions() {
    local current=""
    current="$(get_current_version)" || current=""

    local version status
    while IFS= read -r version; do
        [[ -z "$version" ]] && continue

        status=""
        if version_is_installed "$version"; then
            if [[ -n "$current" && "$version" == "$current" ]]; then
                status="installed,current"
            else
                status="installed"
            fi
        fi
        printf '%s\t%s\n' "$version" "$status"
    done
}

# render_version_list - Formats annotated versions for display (arg: "true"=porcelain, "false"=human)
render_version_list() {
    local porcelain="$1"
    local version status
    while IFS=$'\t' read -r version status; do
        [[ -z "$version" ]] && continue

        local suffix=""
        case "$status" in
            installed,current) suffix=" (installed, current)";;
            installed)         suffix=" (installed)";;
        esac

        if [[ "$porcelain" == true ]]; then
            printf '%s%s\n' "$version" "$suffix"
        else
            printf '  %s%s\n' "$version" "$suffix"
        fi
    done
}

# create_wrapper_script
# --------------------
# Creates a version-aware launcher for Claude Code at the specified path.
#
# Arguments:
#   $1 - Absolute or relative path to the wrapper to create
#        (e.g., "$HOME/.local/bin/claude")
#
# Behavior:
#   - Ensures the parent directory exists.
#   - Writes a Bash wrapper that:
#       * Computes XDG-style directories from environment with sane defaults.
#       * Validates that "$XDG_DATA_HOME/claude/current" is a symlink to a
#         version directory and that required binaries exist and are executable.
#       * Supports maintenance modes:
#             --check         : validate installation, print success, exit 0/1
#             --check-version : validate then print the current version only
#       * Prepends the version’s nodejs/bin to PATH and execs "claude".
#
# Exit status:
#   0 - Wrapper created and marked executable.
#   1 - Failed to set executable bit (or other local error).
#
# Notes:
#   - The heredoc is single-quoted to prevent expansion while generating.
#   - Wrapper uses /bin/bash for compatibility with macOS Bash 3.2.
create_wrapper_script() {
    local target_binary="$1"

    log_debug "create_wrapper_script(~${target_binary/#$HOME})"

    # Create parent directory if needed
    mkdir -p "$(dirname "$target_binary")"

    # Create wrapper script that points to current version
    cat > "$target_binary" << 'EOF'
#!/bin/bash
# Claude Code Version-Aware Wrapper Script
# This script automatically executes the currently selected Claude Code version.

# XDG Base Directory Specification compliance (with custom XDG_HOME fallback)
XDG_HOME="${XDG_HOME:-$HOME}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$XDG_HOME/.local/share}"
CLAUDE_DATA_DIR="${CLAUDE_DATA_DIR:-$XDG_DATA_HOME/claude}"

# Current version symlink path (should point to .../versions/<version>)
CLAUDE_CURRENT_DIR="$CLAUDE_DATA_DIR/current"

# Print error to stderr
_err() { printf '%s\n' "$*" >&2; }

# Comprehensive validation function
validate_installation() {
    # Check if current symlink exists and is a symlink
    if [[ ! -L "$CLAUDE_CURRENT_DIR" ]]; then
        _err "Error: current symlink does not exist: $CLAUDE_CURRENT_DIR"
        return 1
    fi

    # Check if symlink target exists and is a directory
    if [[ ! -d "$CLAUDE_CURRENT_DIR" ]]; then
        _err "Error: current symlink points to non-existent directory: $CLAUDE_CURRENT_DIR"
        return 1
    fi

    # Get the symlink target and verify it's under a versions directory
    local symlink_target
    symlink_target=$(readlink "$CLAUDE_CURRENT_DIR" 2>/dev/null) || symlink_target=""
    if [[ -z "$symlink_target" ]] || { [[ "$symlink_target" != *"/versions/"* ]] && [[ "$symlink_target" != "versions/"* ]]; }; then
        _err "Error: current symlink does not point under a versions directory: ${symlink_target:-<empty>}"
        return 1
    fi

    # Check Node.js layout and executables
    if [[ ! -d "$CLAUDE_CURRENT_DIR/nodejs" ]]; then
        _err "Error: Node.js directory missing: $CLAUDE_CURRENT_DIR/nodejs"
        return 1
    fi
    if [[ ! -d "$CLAUDE_CURRENT_DIR/nodejs/bin" ]]; then
        _err "Error: Node.js bin directory missing: $CLAUDE_CURRENT_DIR/nodejs/bin"
        return 1
    fi
    if [[ ! -x "$CLAUDE_CURRENT_DIR/nodejs/bin/node" ]]; then
        _err "Error: node binary missing or not executable: $CLAUDE_CURRENT_DIR/nodejs/bin/node"
        return 1
    fi
    if [[ ! -x "$CLAUDE_CURRENT_DIR/nodejs/bin/claude" ]]; then
        _err "Error: claude binary missing or not executable: $CLAUDE_CURRENT_DIR/nodejs/bin/claude"
        return 1
    fi

    return 0
}

# Extract version from symlink target; prints without trailing newline
get_current_version() {
    local symlink_target
    symlink_target=$(readlink "$CLAUDE_CURRENT_DIR" 2>/dev/null) || return 1
    [[ -n "$symlink_target" ]] || return 1
    # Strip up to and including 'versions/'
    printf '%s' "${symlink_target#*versions/}"
}

# Handle --check option for installation verification
if [[ "$1" == "--check" ]]; then
    shift
    if [[ $# -ne 0 ]]; then
        _err "Error: --check takes no arguments"
        exit 2
    fi
    if validate_installation; then
        printf '%s\n' "Claude wrapper checked successfully"
        exit 0
    else
        exit 1
    fi
fi

# Handle --check-version option
if [[ "$1" == "--check-version" ]]; then
    shift
    if [[ $# -ne 0 ]]; then
        _err "Error: --check-version takes no arguments"
        exit 2
    fi
    if validate_installation && get_current_version; then
        printf '\n'
        exit 0
    else
        exit 1
    fi
fi

# Perform validation before executing Claude
if ! validate_installation; then
    _err "Run 'claude-toolkit reinstall' to reinstall Claude Code"
    exit 1
fi

# Add version-specific Node.js and npm to PATH
NODE_BIN_DIR="$CLAUDE_CURRENT_DIR/nodejs/bin"
export PATH="$NODE_BIN_DIR:$PATH"

# Execute Claude from current version with proper Node.js PATH
exec "$NODE_BIN_DIR/claude" "$@"
EOF

    # Make wrapper script executable
    if ! chmod 0755 "$target_binary" 2>/dev/null; then
        log_error "Failed to make wrapper script executable: $target_binary"
        return 1
    fi

    return 0
}

# get_wrapper_script_version - Queries wrapper for current version (fails if wrapper missing/broken)
get_wrapper_script_version() {
    local bin_dir
    bin_dir="$(get_xdg_bin_dir)"

    local claude_wrapper="$bin_dir/claude"
    if [[ ! -x "$claude_wrapper" ]]; then
        log_error "Claude wrapper script not found or not executable: ~${claude_wrapper/#$HOME}"
        return 1
    fi

    local version
    if ! version="$("$claude_wrapper" --check-version)"; then
        log_error "Failed to get Claude Code version from wrapper: ~${claude_wrapper/#$HOME}"
        return 1
    fi
    # Defensive: empty output shouldn't happen; treat as error.
    if [[ -z "$version" ]]; then
        log_error "Wrapper returned empty version: ~${claude_wrapper/#$HOME}"
        return 1
    fi

    # Print without trailing newline
    printf '%s' "$version"
    return 0
}

# set_default_version - Atomically sets version as current (creates wrapper, validates target exists)
set_default_version() {
    # Args
    if [[ $# -ne 1 ]]; then
        log_error "set_default_version: exactly one argument required"
        return 2
    fi
    local version="$1"
    if [[ -z "$version" ]]; then
        log_error "Version must not be empty"
        return 2
    fi
    if [[ "$version" == */* ]]; then
        log_error "Invalid version name (must not contain '/'): $version"
        return 2
    fi

    log_debug "set_default_version($version)"

    local bin_dir;             bin_dir="$(get_xdg_bin_dir)"
    local claude_current_dir;  claude_current_dir="$(get_claude_current_dir)"
    local current_parent;      current_parent="$(dirname "$claude_current_dir")"
    local versions_dir;        versions_dir="$(get_claude_versions_dir)"
    local version_dir="$versions_dir/$version"

    # Ensure parent dir exists
    mkdir -p "$current_parent"

    # Validate version is installed
    if [[ ! -d "$version_dir" ]]; then
        log_error "Version not installed: $version (expected dir: ~${version_dir/#$HOME})"
        return 1
    fi

    local relative_version_path="versions/$version"

    # Use atomic symlink creation function
    if ! create_atomic_symlink "$claude_current_dir" "$relative_version_path"; then
        return 1
    fi

    # Verify (optional but useful)
    local new_version
    if new_version="$(get_current_version)"; then
        if [[ "$new_version" != "$version" ]]; then
            log_error "Symlink verification mismatch: wanted $version, got $new_version"
            return 1
        fi
    else
        log_error "Symlink verification failed: get_current_version returned no value"
        return 1
    fi

    # (Re)create wrapper; propagate error
    if ! create_wrapper_script "$bin_dir/claude"; then
        log_error "Failed to (re)create wrapper script at: ~${bin_dir/#$HOME}/claude"
        return 1
    fi

    return 0
}

# remove_all_claude_versions_ - Internal function: removes all installations and infrastructure
remove_all_claude_versions_() {
    local target_shell="$1"

    log_debug "remove_all_claude_versions_"

    local claude_data_dir
    claude_data_dir="$(get_claude_data_dir)"

    if [[ -d "$claude_data_dir" ]]; then
        rm -rf "$claude_data_dir"
        log_debug "remove_all_claude_versions_: Removed all Claude Code data: ~${claude_data_dir/#$HOME}"
    fi

    local bin_dir
    bin_dir="$(get_xdg_bin_dir)"

    local claude_wrapper="$bin_dir/claude"

    if [[ -f "$claude_wrapper" ]]; then
        rm -f "$claude_wrapper"
        log_debug "remove_all_claude_versions_: Removed Claude Code wrapper script: ~${claude_wrapper/#$HOME}"
    fi

    local claude_cache_dir
    claude_cache_dir="$(get_claude_cache_dir)"

    if [[ -d "$claude_cache_dir" ]]; then
        rm -rf "$claude_cache_dir"
        log_debug "remove_all_claude_versions_: Removed cache directory: ~${claude_cache_dir/#$HOME}"
    fi

    cleanup_shell_configurations "$target_shell"

    return 0
}

remove_all_claude_versions() {
    local target_shell="$1"
    log_debug "remove_all_claude_versions"
    log_info "Removing all Claude Code versions and infrastructure..."

    remove_all_claude_versions_ "$target_shell"

    log_success "Removed all Claude Code versions and infrastructure"
    return 0
}

# Remove a specific Claude Code version with smart switching
remove_claude_version() {
    local version_to_remove="$1"
    local target_shell="$2"

    log_debug "remove_claude_version($version_to_remove)"
    log_info "Removing Claude Code version $version_to_remove..."

    # Validate version exists
    if ! version_is_installed "$version_to_remove"; then
        log_error "Version $version_to_remove is not installed - nothing to remove."
        return 1
    fi

    local was_current_version
    if is_current_version "$version_to_remove"; then
      was_current_version=0
    else
      was_current_version=$?
    fi

    # Directory to be removed (:? to protect from accidental removal of root directory)
    local claude_versions_dir
    claude_versions_dir="$(get_claude_versions_dir)"
    local remove_dir="${claude_versions_dir:?}/$version_to_remove"

    if ! remove_output=$(rm -rf "$remove_dir"); then
      log_error "Failed to remove directory $remove_dir"
      log_error "$remove_output"
      return 1
    fi

    log_success "Removed Claude Code version $version_to_remove"

    # Count remaining versions using stream
    local remaining_version_count
    remaining_version_count="$(get_installed_versions_count)"

    # Handle post-removal switching if removing current version
    if [[ $was_current_version -eq 0 ]]; then
        log_info "Removed version was the current version, checking for installed versions..."

        if [[ remaining_version_count -gt 0 ]]; then
            # At least one version remaining - switch to latest
            local latest_version
            latest_version=$(get_latest_installed_version)
            log_info "Switching to latest installed version: $latest_version"

            if ! set_default_version "$latest_version"; then
                log_error "Failed to switch to latest version: $latest_version"
                return 1
            fi

            log_success "Switched to latest installed version: $latest_version"
        fi
    else
        log_info "Removed non-current version, preserving existing infrastructure"
    fi

    if [[ remaining_version_count -eq 0 ]]; then
        # No versions remaining - cleanup infrastructure
        log_info "No versions installed."
        log_info "Cleaning up Claude Code infrastructure..."
        remove_all_claude_versions_ "$target_shell"
        log_success "Cleaned up Claude Code infrastructure"
    fi

    log_debug "remove_claude_version: OK"
    return 0
}

check_os_version() {
    log_debug "check_os_version"
    log_info "Checking OS version..."

    local os_type
    os_type="$(get_os_type)"
    
    case "$os_type" in
        Darwin)
            # Check macOS version (10.15+)
            local macos_version
            macos_version=$(sw_vers -productVersion | cut -d. -f1,2)
            local required_version="10.15"
            if [[ $(echo "$macos_version >= $required_version" | bc 2>/dev/null || echo "0") != "1" ]]; then
                log_error "macOS 10.15+ required, found: $macos_version"
                exit 1
            fi
            ;;
        Linux)
            # Check if we have basic glibc support (most Linux distributions should work)
            if ! command -v ldd >/dev/null 2>&1; then
                log_warning "Cannot verify glibc version (ldd not found), proceeding anyway"
            else
                # Try to get glibc version - this is best effort
                local glibc_version
                if glibc_version=$(ldd --version 2>/dev/null | head -n1 | grep -o '[0-9]\+\.[0-9]\+' | head -n1); then
                    log_debug "Detected glibc version: $glibc_version"
                    # Most modern Linux distributions should work, no hard requirement
                else
                    log_debug "Could not detect glibc version, proceeding anyway"
                fi
            fi
            ;;
        *)
            log_error "Unsupported operating system: $os_type"
            log_info "This script supports macOS and Linux only"
            exit 1
            ;;
    esac

    log_success "Checked OS version"
    log_debug "check_os_version: OK"
}

check_target_shell() {
    local target_shell="$1"
    log_debug "check_target_shell($target_shell)"
    log_info "Checking target shell..."

    # Validate target shell if specified
    if [[ -n "$target_shell" ]]; then
        if ! command -v "$target_shell" >/dev/null 2>&1; then
            log_error "Specified shell not found: $target_shell"
            exit 1
        fi

        case "$target_shell" in
            bash|zsh|fish)
                ;;
            *)
                log_error "Unsupported shell: $target_shell (supported: bash, zsh, fish)"
                exit 1
                ;;
        esac
    fi

    log_success "Checked target shell"
    log_debug "check_target_shell: OK"
}

check_network_connection() {
    log_debug "check_network_connection"
    log_info "Checking network connection..."

    # Check internet connection using HTTP instead of ping (more reliable in corporate environments)
    if ! curl -s --max-time 5 --head https://artifacts.apple.com >/dev/null 2>&1; then
        log_error "Internet connection required to download Node.js"
        exit 1
    fi

    log_success "Checked network connection"
    log_debug "check_network_connection: OK"
}

check_required_commands() {
    log_debug "check_required_commands"
    log_info "Checking required commands..."

    # Check required commands
    for cmd in curl tar; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Required command not found: $cmd"
            exit 1
        fi
    done

    log_success "Checked required commands"
    log_debug "check_required_commands: OK"
}

check_install_prerequisites() {
    local target_shell="$1"
    log_debug "check_install_prerequisites($target_shell)"

    check_os_version
    check_target_shell "$target_shell"
    check_network_connection
    check_required_commands

    log_debug "check_install_prerequisites: OK"
}



check_installation_integrity() {
    local target_version=${1:-}
    local expected_current_version=${2:-}

    log_debug "verify_installation_integrity($target_version)"
    log_info "Verifying integrity of installation..."

    if [[ ! -d "$(get_claude_versions_dir)/$target_version" ]]; then
        log_error "Version directory missing after reinstall: $(get_claude_versions_dir | sed "s|^$HOME|~|")/$target_version"
        return 1
    fi

    if [[ "$expected_current_version" != "$target_version" ]] && [[ ! -d "$(get_claude_versions_dir)/$expected_current_version" ]]; then
        log_error "Version directory missing after reinstall: $(get_claude_versions_dir | sed "s|^$HOME|~|")/$expected_current_version"
        return 1
    fi

    wrapper_script_version="$(get_wrapper_script_version)"

    log_debug "verify_installation: wrapper_script_version=$wrapper_script_version"

    if [[ "$wrapper_script_version" != "$expected_current_version" ]]; then
        log_error "Wrapper script version $wrapper_script_version does not match expected version $expected_current_version"
        return 1
    fi

    log_success "Verified integrity of installation"
    log_debug "verify_installation_integrity: OK"
    return 0
}

# Display post-installation information for version-aware setup
show_post_install_info() {
    local target_version="$1"
    local target_shell="$2"

    log_debug "show_post_install_info"
    
    echo ""
    echo -e "${BLUE}Installed Claude Code Version:${NC} $target_version"

    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "  1. Open a new terminal or reload your shell configuration:"
    
    if [[ -n "$target_shell" ]]; then
        local config_file
        config_file=$(get_shell_config_file "$target_shell")
        echo "     $target_shell: source ~${config_file/#$HOME}"
    else
        # Use stream processing instead of arrays
        detect_available_shells | while read -r target_shell; do
            [[ -z "$target_shell" ]] && continue
            local config_file
            config_file=$(get_shell_config_file "$target_shell")
            echo "     $target_shell: source ~${config_file/#$HOME}"
        done
    fi
    
    echo "  2. Navigate to your project: cd /path/to/your/project"
    echo "  3. Start Claude Code: claude"
    echo "  4. Initialize project: /init (inside Claude) - typically done only once"
    echo ""

    log_debug "show_post_install_info: OK"
}

# Enhanced cleanup function for error handling - version-aware
cleanup_install_on_error() {
    local target_dir="$1"
    local target_shell="$2"
    log_debug "cleanup_install_on_error(~${target_dir/#$HOME}, $target_shell)"
    
    # Remove version-specific directory if it was created for this installation
    if [[ -d "$target_dir" ]]; then
        log_debug "cleanup_install_on_error: Removing failed version installation: ~${target_dir/#$HOME}"
        rm -rf "$target_dir"
    fi
    
    # Check if any versions remain after cleanup
    local remaining_versions
    remaining_versions="$(get_installed_versions)"
    if [[ -z "$remaining_versions" ]]; then
        # No versions remaining - use the standard infrastructure cleanup
        log_debug "cleanup_install_on_error: No versions remain, cleaning up infrastructure"
        remove_all_claude_versions_ "$target_shell"
    else
        log_debug "cleanup_install_on_error: Other versions remain, preserving infrastructure"
    fi

    log_debug "cleanup_install_on_error: OK"
}

create_install_directories() {
    local target_version="${1:-}"

    log_debug "create_install_directories($target_version)"
    log_info "Creating installation directories..."

    # Create base directories
    mkdir -p "$(get_claude_data_dir)"
    log_debug "Created directory $(get_claude_data_dir | sed "s|^$HOME|~|")"
    mkdir -p "$(get_claude_cache_dir)"
    log_debug "Created directory $(get_claude_cache_dir | sed "s|^$HOME|~|")"
    mkdir -p "$(get_xdg_bin_dir)"
    log_debug "Created directory $(get_xdg_bin_dir | sed "s|^$HOME|~|")"
    mkdir -p "$(get_claude_versions_dir)"
    log_debug "Created directory $(get_claude_versions_dir | sed "s|^$HOME|~|")"
    mkdir -p "$(get_claude_versions_dir)/$target_version"
    log_debug "Created directory $(get_claude_versions_dir | sed "s|^$HOME|~|")/$target_version"

    log_success "Created installation directories"
    log_debug "create_install_directories: OK"
}

# Install dedicated Node.js for registry queries (self-contained)
install_registry_tools() {
    local nodejs_version="$1"
    local cache_dir="$2"

    log_debug "install_registry_tools($nodejs_version)"

    local target_dir
    target_dir="$(get_claude_registry_tools_dir)"
    local nodejs_dir="$target_dir/nodejs"

    # Skip if already installed
    if [[ -f "$nodejs_dir/bin/node" ]] && [[ -f "$nodejs_dir/bin/npm" ]]; then
        log_debug "install_registry_tools: OK (already installed)"
        return 0
    fi

    log_info "Installing registry tools..."

    install_nodejs "$target_dir" "$nodejs_version" "$cache_dir"
    configure_npm_rc "$target_dir" "$cache_dir"

    log_success "Installed registry tools"
}

# Show version management guidance based on installation state
show_version_management_guidance() {
    local installed_versions="$1"

    local installed_versions_count
    installed_versions_count=$(echo "$installed_versions" | wc -l | tr -d ' ')

    if [[ $installed_versions_count -eq 0 ]]; then
        echo "No Claude Code versions are currently installed."
        echo ""
        echo "To install a version, use: claude-code install --version <version>"
    elif [[ $installed_versions_count -eq 1 ]]; then
        echo ""
        echo "To install additional versions, use: claude-code install --version <version>"
    else
        echo ""
        echo "To install additional versions, use: claude-code install --version <version>"
        echo "To switch between installed versions, use: claude-code use --version <version>"
    fi
}

# List Claude Code versions with shared guidance system
list_claude_versions() {
    local mode="$1"
    local porcelain="$2"
    local nodejs_version="$3"

    log_function "list_claude_versions($mode)"

    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    case "$mode" in
        "installed")
            local installed_versions
            installed_versions="$(get_installed_versions)"

            if [[ -z "$installed_versions" ]]; then
                if [[ "$porcelain" != true ]]; then
                    show_version_management_guidance "$installed_versions"
                fi
                return 0
            fi

            if [[ "$porcelain" != true ]]; then
                echo "Installed versions:"
            fi
            echo "$installed_versions" | /usr/bin/sort -V | annotate_versions | render_version_list "$porcelain"
            if [[ "$porcelain" != true ]]; then
                show_version_management_guidance "$installed_versions"
            fi
            ;;

        "available")
            log_debug "list_claude_versions: Querying available versions from npm registry..."

            # Install registry tools for version queries
            if ! install_registry_tools "$nodejs_version" "$(get_claude_cache_dir)" >/dev/null; then
                log_error "Failed to install registry tools"
                return 1
            fi

            if ! query_available_versions_output=$(query_available_claude_package_versions "$(get_claude_registry_tools_dir)"); then
                if [[ "$porcelain" != true ]]; then
                    echo "No Claude Code versions found in npm registry"
                fi
                echo "$query_available_versions_output" >&2
                return 0
            fi

            local installed_versions
            installed_versions="$(get_installed_versions)"

            if [[ "$porcelain" != true ]]; then
                echo "Available versions:"
            fi
            echo "$query_available_versions_output" | /usr/bin/sort -V | annotate_versions | render_version_list "$porcelain"
            if [[ "$porcelain" != true ]]; then
                show_version_management_guidance "$installed_versions"
            fi
            ;;

        *)
            log_error "Invalid list mode: $mode"
            log_info "Valid modes: available, installed"
            exit 1
            ;;
    esac
}

install_claude_code() {
    local target_version="$1"
    local target_shell="$2"
    local nodejs_version="$3"

    log_function "install_claude_code($target_version)"

    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    log_info "Starting Claude Code installation..."

    check_install_prerequisites "$target_shell"

    if [[ -z "${target_version}" ]]; then
        log_info "Version to install not specified, assuming the latest version is requested"
        # Install registry tools for version queries
        if ! install_registry_tools "$nodejs_version" "$(get_claude_cache_dir)" >/dev/null; then
            log_error "Failed to install registry tools"
            return 1
        fi
        # Querying latest version uses registry tools
        if ! target_version=$(query_latest_claude_package_version "$(get_claude_registry_tools_dir)"); then
            log_error "Failed to retrieve the latest version of Claude Code from npm"
            return 1
        fi
        log_info "Latest version: ${target_version}"
    fi

    if version_is_installed "$target_version"; then
        log_info "Version $target_version is already installed."
        log_info "Use uninstall to remove or specify a different version with --version <version>"
        return 0
    fi

    log_info "Installing version: $target_version"

    local target_dir
    target_dir="$(get_claude_versions_dir)/$target_version"

    # Run main logic in subshell to isolate traps
    (
        trap 'cleanup_install_on_error "'"$target_dir"'" "'"$target_shell"'"' ERR
        trap 'cleanup_install_on_error "'"$target_dir"'" "'"$target_shell"'"' EXIT

        create_install_directories "$target_version"

        install_nodejs "$target_dir" "$nodejs_version" "$(get_claude_cache_dir)"
        configure_npm_rc "$target_dir" "$(get_claude_cache_dir)"
        install_claude_code_npm_package "$target_version" "$target_dir"
        set_default_version "$target_version"
        update_shell_configs "$target_shell"

        trap - ERR
        trap - EXIT
    ) || return $?

    if ! check_installation_integrity "$target_version" "$target_version"; then
        log_error "Installation completed but integrity check failed"
        cleanup_install_on_error "$target_dir" "$target_shell"
        exit 1
    fi

    show_post_install_info "$target_version" "$target_shell"
    log_success "Installation completed successfully!"
    echo ""
    return 0
}

# Create backup of specified version before reinstall
backup_before_reinstall() {
    local target_version="$1"
    log_debug "backup_before_reinstall($target_version)"
    
    local claude_data_dir
    claude_data_dir="$(get_claude_data_dir)"
    local target_dir="$claude_data_dir/versions/$target_version"
    local current_symlink="$claude_data_dir/current"
    local wrapper_script="$(get_xdg_bin_dir)/claude"
    
    # Backup version directory if it exists (copy, don't move)
    if [[ -d "$target_dir" ]]; then
        if [[ -d "$target_dir.bak" ]]; then
            log_debug "backup_before_reinstall: Removing existing backup directory"
            rm -rf "$target_dir.bak"
        fi
        log_debug "backup_before_reinstall: Backing up version directory: ~${target_dir/#$HOME}"
        if ! cp -rP "$target_dir" "$target_dir.bak"; then
            log_error "Failed to backup version directory: ~${target_dir/#$HOME}"
            return 1
        fi
    fi
    
    # Backup current symlink if it points to this version (copy, don't move)
    if [[ -L "$current_symlink" ]]; then
        local current_target
        current_target="$(readlink "$current_symlink" 2>/dev/null || echo "")"
        if [[ "$current_target" == "versions/$target_version" ]]; then
            if [[ -L "$current_symlink.bak" ]]; then
                log_debug "backup_before_reinstall: Removing existing backup symlink"
                rm -f "$current_symlink.bak"
            fi
            log_debug "backup_before_reinstall: Backing up current symlink"
            if ! cp -P "$current_symlink" "$current_symlink.bak"; then
                log_error "Failed to backup current symlink"
                # Cleanup version backup if we created it
                [[ -d "$target_dir.bak" ]] && rm -rf "$target_dir.bak"
                return 1
            fi
        fi
    fi
    
    # Backup wrapper script if it exists (copy, don't move)
    if [[ -f "$wrapper_script" ]]; then
        if [[ -f "$wrapper_script.bak" ]]; then
            log_debug "backup_before_reinstall: Removing existing backup wrapper script"
            rm -f "$wrapper_script.bak"
        fi
        log_debug "backup_before_reinstall: Backing up wrapper script"
        if ! cp "$wrapper_script" "$wrapper_script.bak"; then
            log_error "Failed to backup wrapper script"
            # Cleanup previous backups if we created them
            [[ -L "$current_symlink.bak" ]] && rm -f "$current_symlink.bak"
            [[ -d "$target_dir.bak" ]] && rm -rf "$target_dir.bak"
            return 1
        fi
    fi
    
    log_debug "backup_before_reinstall: Backup completed successfully"
    return 0
}

# Clean up backup files after successful reinstall
cleanup_backup_after_successful_reinstall() {
    local target_version="$1"
    log_debug "cleanup_backup_after_successful_reinstall($target_version)"
    
    local claude_data_dir
    claude_data_dir="$(get_claude_data_dir)"
    local target_dir="$claude_data_dir/versions/$target_version"
    local current_symlink="$claude_data_dir/current"
    local wrapper_script="$(get_xdg_bin_dir)/claude"
    
    # Remove backup version directory
    if [[ -d "$target_dir.bak" ]]; then
        log_debug "cleanup_backup_after_successful_reinstall: Removing backup version directory"
        rm -rf "$target_dir.bak"
    fi
    
    # Remove backup current symlink
    if [[ -L "$current_symlink.bak" ]]; then
        log_debug "cleanup_backup_after_successful_reinstall: Removing backup current symlink"
        rm -f "$current_symlink.bak"
    fi
    
    # Remove backup wrapper script
    if [[ -f "$wrapper_script.bak" ]]; then
        log_debug "cleanup_backup_after_successful_reinstall: Removing backup wrapper script"
        rm -f "$wrapper_script.bak"
    fi
    
    log_debug "cleanup_backup_after_successful_reinstall: Cleanup completed"
}

# Restore from backup on failed reinstall
restore_after_failed_reinstall() {
    local target_version="$1"
    log_debug "restore_after_failed_reinstall($target_version)"
    
    local claude_data_dir
    claude_data_dir="$(get_claude_data_dir)"
    local target_dir="$claude_data_dir/versions/$target_version"
    local current_symlink="$claude_data_dir/current"
    local wrapper_script="$(get_xdg_bin_dir)/claude"
    
    log_info "Restoring from backup after failed reinstall..."
    
    # Restore version directory
    if [[ -d "$target_dir.bak" ]]; then
        log_debug "restore_after_failed_reinstall: Restoring version directory"
        
        # Handle conflict: remove partially created directory
        if [[ -d "$target_dir" ]]; then
            log_debug "restore_after_failed_reinstall: Removing partially created version directory"
            rm -rf "$target_dir"
        fi
        
        if ! mv "$target_dir.bak" "$target_dir"; then
            log_error "Failed to restore version directory from backup"
            return 1
        fi
        log_debug "restore_after_failed_reinstall: Version directory restored successfully"
    fi
    
    # Restore current symlink
    if [[ -L "$current_symlink.bak" ]]; then
        log_debug "restore_after_failed_reinstall: Restoring current symlink"
        
        # Handle conflict: remove partially created symlink
        if [[ -L "$current_symlink" || -e "$current_symlink" ]]; then
            log_debug "restore_after_failed_reinstall: Removing partially created current symlink"
            rm -f "$current_symlink"
        fi
        
        if ! mv "$current_symlink.bak" "$current_symlink"; then
            log_error "Failed to restore current symlink from backup"
            return 1
        fi
        log_debug "restore_after_failed_reinstall: Current symlink restored successfully"
    fi
    
    # Restore wrapper script
    if [[ -f "$wrapper_script.bak" ]]; then
        log_debug "restore_after_failed_reinstall: Restoring wrapper script"
        
        # Handle conflict: remove partially created wrapper script
        if [[ -f "$wrapper_script" ]]; then
            log_debug "restore_after_failed_reinstall: Removing partially created wrapper script"
            rm -f "$wrapper_script"
        fi
        
        if ! mv "$wrapper_script.bak" "$wrapper_script"; then
            log_error "Failed to restore wrapper script from backup"
            return 1
        fi
        log_debug "restore_after_failed_reinstall: Wrapper script restored successfully"
    fi
    
    log_info "Backup restoration completed successfully"
    return 0
}

reinstall_claude_code() {
    local target_version="$1"
    local target_shell="$2"
    local nodejs_version="$3"

    log_function "reinstall_claude_code($target_version)"

    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    log_info "Starting Claude Code reinstall..."

    check_install_prerequisites "$target_shell"

    if [[ -z "${target_version}" ]]; then
        log_info "Version to reinstall not specified, assuming the current version is requested"
        if ! target_version="$(get_current_version)"; then
            log_error "No current version found, nothing to reinstall."
            exit 1
        fi
        log_info "Current version: $target_version"
    fi

    log_info "Reinstalling version: $target_version"

    # Validate that target version is currently installed
    if ! version_is_installed "$target_version"; then
        log_error "Version $target_version is not installed"
        log_info "Installed versions: $(get_installed_versions | tr '\n' ' ')"
        return 1
    fi

    local current_version_before_reinstall
    if ! current_version_before_reinstall="$(get_current_version)"; then
        current_version_before_reinstall=""
    fi

    # Remember if this version was the current version before reinstall
    local was_current_version=false
    if [[ "$current_version_before_reinstall" == "$target_version" ]]; then
        was_current_version=true
        log_debug "reinstall_claude_code: Target version $target_version is the current version"
    else
        log_debug "reinstall_claude_code: Target version $target_version is not the current version"
    fi

    if ! backup_before_reinstall "$target_version"; then
        log_error "Failed to create backup before reinstall"
        return 1
    fi

    if ! remove_claude_version "$target_version" "$target_shell"; then
        log_error "Failed to remove version during reinstall"
        restore_after_failed_reinstall "$target_version"
        return 1
    fi

    # Run main logic in subshell to isolate traps
    (
        local target_dir
        target_dir="$(get_claude_versions_dir)/$target_version"

        trap 'restore_after_failed_reinstall "'"$target_version"'"' ERR

        create_install_directories "$target_version"

        install_nodejs "$target_dir" "$nodejs_version" "$(get_claude_cache_dir)"
        configure_npm_rc "$target_dir" "$(get_claude_cache_dir)"
        install_claude_code_npm_package "$target_version" "$target_dir"

        # Only set as default if it was the current version before reinstall
        if [[ "$was_current_version" == true ]]; then
            log_debug "reinstall_claude_code: Restoring as default version since it was current before reinstall"
            set_default_version "$target_version"
        else
            log_debug "reinstall_claude_code: Not setting as default version since it was not current before reinstall"
            # Just create the wrapper script to ensure it's available
            create_wrapper_script "$(get_xdg_bin_dir)/claude"
        fi

        update_shell_configs "$target_shell"
    ) || return $?

    if ! check_installation_integrity "$target_version" "$current_version_before_reinstall"; then
        log_error "Reinstallation completed but integrity check failed"
        restore_after_failed_reinstall "$target_version"
        return 1
    fi

    # Clean up backup files after successful reinstall
    cleanup_backup_after_successful_reinstall "$target_version"

    show_post_install_info "$target_version" "$target_shell"
    log_success "Reinstall completed successfully!"
    echo ""
    return 0
}

uninstall_claude_code() {
    local target_version="$1"
    local all_flag="$2"
    local target_shell="$3"

    log_function "uninstall_claude_code"

    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    log_info "Starting Claude Code uninstall..."

    if [[ "$all_flag" == true ]]; then
        # Remove all versions and complete infrastructure
        remove_all_claude_versions "$target_shell"
    elif [[ -n "$target_version" ]]; then
        # Remove specific version with smart switching
        remove_claude_version "$target_version" "$target_shell"
    else
        # Remove current version
        local current_version
        if ! current_version="$(get_current_version)"; then
            log_error "No current version found to uninstall"
            return 1
        fi
        log_info "No version specified, removing current version: $current_version"
        remove_claude_version "$current_version" "$target_shell"
    fi
}

# Use Claude Code version (switch to installed version or show version info)
use_claude_version() {
    local target_version="$1"
    local porcelain="$2"
    local nodejs_version="$3"

    log_function "use_claude_version($target_version)"

    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    # If no version specified, delegate to list installed versions
    if [[ -z "$target_version" ]]; then
        list_claude_versions "installed" "$porcelain" "$nodejs_version"
        return 0
    fi

    log_info "Switching to Claude Code version $target_version..."

    # Validate target version is installed
    if ! version_is_installed "$target_version"; then
        log_error "Could not switch to version $target_version, because it is not installed"
        list_claude_versions "installed" "$porcelain" "$nodejs_version"
        return 1
    fi

    # Check if target version is already current
    if is_current_version "$target_version"; then
        log_info "Version $target_version is already the current version"
        log_info "No changes needed"
        return 0
    fi

    # Validate target version installation integrity before switching
    local target_dir="$(get_claude_versions_dir)/$target_version"
    if [[ ! -d "$target_dir/nodejs" ]]; then
        log_error "Version $target_version installation appears corrupted (missing nodejs directory)"
        log_info "Reinstall version with: claude-code reinstall --version $target_version"
        return 1
    fi

    if [[ ! -f "$target_dir/nodejs/bin/claude" ]]; then
        log_error "Version $target_version installation appears corrupted (missing claude binary)"
        log_info "Reinstall version with: claude-code reinstall --version $target_version"
        return 1
    fi

    log_debug "Target version $target_version validation successful"

    # Switch to target version using existing symlink management
    if ! set_default_version "$target_version"; then
        log_error "Failed to switch to version $target_version"
        return 1
    fi

    log_success "Successfully switched to version $target_version"
    log_info "Verify with: claude --check-version"

    log_debug "use_claude_version: OK"
    return 0
}

show_help() {
    echo "Claude Code Installation Script"
    echo ""
    echo "Usage: claude-code <command> [options]"
    echo ""
    echo "Commands:"
    echo "  install                Install Claude Code"
    echo "  uninstall              Remove Claude Code installation"
    echo "  reinstall              Reinstall existing version"
    echo "  use                    Switch to installed version or show version info"
    echo "  list                   List Claude Code versions"
    echo ""
    echo "Global Options:"
    echo "  --dry-run              Print function names without executing (dry run mode)"
    echo "  --debug                Enable debug output (verbose logging)"
    echo "  --porcelain            Enable porcelain format (machine-readable output)"
    echo "  --help, -h             Show this help message"
    echo ""
    echo "Install Command Options:"
    echo "  --version <version>    Install specific version (default: latest)"
    echo "  --nodejs-version <ver> Use specific Node.js version (default: 22.17.1)"
    echo "  --shell <shell>        Target specific shell (bash, zsh, fish)"
    echo ""
    echo "Uninstall Command Options:"
    echo "  --version <version>    Remove specific version (default: current version)"
    echo "  --all                  Remove all versions and infrastructure"
    echo ""
    echo "Reinstall Command Options:"
    echo "  --version <version>    Reinstall specific version (default: current version)"
    echo "  --nodejs-version <ver> Use specific Node.js version"
    echo "  --shell <shell>        Target specific shell"
    echo ""
    echo "Use Command Options:"
    echo "  --version <version>    Switch to specific installed version"
    echo "                         (omit to show current version information)"
    echo ""
    echo "List Command Options:"
    echo "  --mode <mode>          List mode: available (default) or installed"
    echo ""
    echo "Examples:"
    echo "  claude-code install                          # Install latest version"
    echo "  claude-code install --version 1.2.3          # Install specific version"
    echo "  claude-code install --nodejs-version 22.18.0 # Install with specific Node.js"
    echo "  claude-code uninstall                        # Remove current version"
    echo "  claude-code uninstall --version 1.2.3        # Remove specific version"
    echo "  claude-code uninstall --all                  # Remove all versions"
    echo "  claude-code reinstall                        # Reinstall current version"
    echo "  claude-code reinstall --nodejs-version 22.18.0 # Reinstall with different Node.js"
    echo "  claude-code use                              # Show current version info"
    echo "  claude-code use --version 1.2.3              # Switch to installed version"
    echo "  claude-code list                             # List all available versions"
    echo "  claude-code list --mode installed            # List only installed versions"
    echo ""
    echo "Supported shells: bash, zsh, fish"
    echo "Supported platforms: macOS, Linux"
    echo "Installation follows XDG Base Directory specification"
}

# Parse command line arguments - pure syntactic parsing, returns key-value pairs
parse_arguments() {
    # Handle global help flag first
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        printf 'help\ttrue\n'
        return 0
    fi

    # Extract command if provided, or mark as missing
    if [[ $# -eq 0 ]]; then
        printf 'no_command\ttrue\n'
    else
        local command="$1"
        shift
        printf 'command\t%s\n' "$command"
    fi

    # Parse all options syntactically - no validation
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                if [[ -n "${2:-}" ]] && [[ "$2" != --* ]]; then
                    printf "version\t%s\n" "$2"
                    shift 2
                else
                    printf "version_no_value\ttrue\n"
                    shift
                fi
                ;;
            --version=*)
                printf "version\t%s\n" "${1#*=}"
                shift
                ;;
            --nodejs-version)
                if [[ -n "${2:-}" ]] && [[ "$2" != --* ]]; then
                    printf "nodejs_version\t%s\n" "$2"
                    shift 2
                else
                    printf "nodejs_version_no_value\ttrue\n"
                    shift
                fi
                ;;
            --nodejs-version=*)
                printf "nodejs_version\t%s\n" "${1#*=}"
                shift
                ;;
            --shell)
                if [[ -n "${2:-}" ]] && [[ "$2" != --* ]]; then
                    printf "shell\t%s\n" "$2"
                    shift 2
                else
                    printf "shell_no_value\ttrue\n"
                    shift
                fi
                ;;
            --shell=*)
                printf "shell\t%s\n" "${1#*=}"
                shift
                ;;
            --mode)
                if [[ -n "${2:-}" ]] && [[ "$2" != --* ]]; then
                    printf "mode\t%s\n" "$2"
                    shift 2
                else
                    printf "mode_no_value\ttrue\n"
                    shift
                fi
                ;;
            --mode=*)
                printf "mode\t%s\n" "${1#*=}"
                shift
                ;;
            --all)
                printf "all\ttrue\n"
                shift
                ;;
            --dry-run)
                printf "dry_run\ttrue\n"
                shift
                ;;
            --porcelain)
                printf "porcelain\ttrue\n"
                shift
                ;;
            --debug)
                printf "debug\ttrue\n"
                shift
                ;;
            --yes|-y)
                # No-op flag for compatibility (script is already non-interactive)
                printf "yes\ttrue\n"
                shift
                ;;
            --help|-h)
                printf "help_after_command\ttrue\n"
                shift
                ;;
            *)
                printf "unknown_option\t%s\n" "$1"
                shift
                ;;
        esac
    done
}

# Validate parsed arguments for consistency and command-specific requirements
validate_arguments() {
    local command="" mode="" shell="" all_flag=false
    local help_requested=false
    local has_no_command=false

    # Read key-value pairs from stdin and collect validation issues
    while IFS=$'\t' read -r key value; do
        case "$key" in
            command) command="$value" ;;
            mode) mode="$value" ;;
            shell) shell="$value" ;;
            all) all_flag=true ;;
            help) help_requested=true ;;
            no_command) has_no_command=true ;;
            version_no_value)
                printf "%s\n" "--version requires a value"
                return 1
                ;;
            nodejs_version_no_value)
                printf "%s\n" "--nodejs-version requires a value"
                return 1
                ;;
            shell_no_value)
                printf "%s\n" "--shell requires a value"
                return 1
                ;;
            mode_no_value)
                printf "%s\n" "--mode requires a value"
                return 1
                ;;
            help_after_command)
                printf "%s\n" "Use --help before command for usage information"
                return 1
                ;;
            unknown_option)
                printf "Unknown option %s\n" "$value"
                return 1
                ;;
        esac
    done
    
    # Don't validate anything else if help was requested
    if [[ "$help_requested" == true ]]; then
        return 0
    fi
    
    # Validate command exists
    if [[ "$has_no_command" == true ]]; then
        printf "%s\n" "No command specified"
        printf "%s\n" "Commands: install, uninstall, reinstall, use, list"
        return 1
    fi
    
    # Validate command is recognized
    case "$command" in
        install|uninstall|reinstall|use|list)
            ;;
        *)
            printf "Unknown command: %s\n" "$command"
            printf "%s\n" "Valid commands: install, uninstall, reinstall, use, list"
            return 1
            ;;
    esac
    
    # Command-specific option validation
    case "$command" in
        list)
            if [[ -n "$mode" ]]; then
                case "$mode" in
                    available|installed)
                        ;;
                    *)
                        printf "Invalid --mode for 'list' command: %s (valid: available, installed)\n" "$mode"
                        return 1
                        ;;
                esac
            fi
            ;;
        uninstall)
            # --all is only valid for uninstall
            if [[ -n "$mode" ]]; then
                printf "%s\n" "--mode option only valid for 'list' command"
                return 1
            fi
            ;;
        install|reinstall|use)
            if [[ "$all_flag" == true ]]; then
                printf "%s\n" "--all option only valid for 'uninstall' command"
                return 1
            fi
            if [[ -n "$mode" ]]; then
                printf "%s\n" "--mode option only valid for 'list' command"
                return 1
            fi
            ;;
    esac
    
    # Validate shell if specified
    if [[ -n "$shell" ]]; then
        case "$shell" in
            bash|zsh|fish)
                ;;
            *)
                printf "Unsupported shell: %s (supported: bash, zsh, fish)\n" "$shell"
                return 1
                ;;
        esac
    fi
    
    # All validations passed
    return 0
}

# Interpret parsed arguments and set variables
interpret_arguments() {
    local parsed_args="$1"
    local command version nodejs_version shell mode all_flag dry_run porcelain debug help_requested

    # Initialize argument variables with defaults
    command="" 
    version="" 
    nodejs_version="$NODEJS_VERSION"
    shell=""
    mode="available" 
    all_flag=false 
    dry_run="$DRY_RUN" 
    porcelain="$PORCELAIN"
    debug="$DEBUG" 
    help_requested=false
    
    # Read and interpret parsed arguments
    while IFS=$'\t' read -r key value; do
        case "$key" in
            help) help_requested=true ;;
            command) command="$value" ;;
            version) version="$value" ;;
            nodejs_version) nodejs_version="$value" ;;
            shell) shell="$value" ;;
            mode) mode="$value" ;;
            all) all_flag=true ;;
            dry_run) dry_run=true ;;
            porcelain) porcelain=true ;;
            debug) debug=true ;;
        esac
    done <<< "$parsed_args"

    # Handle help request
    if [[ "$help_requested" == true ]]; then
        show_help
        exit 0
    fi

    # Set global environment variables for functions that need them
    DRY_RUN="$dry_run"
    DEBUG="$debug"

    # Run main logic in subshell to isolate traps
    (
        case "$command" in
            "list")
                list_claude_versions "$mode" "$porcelain" "$nodejs_version"
                ;;
            "install")
                install_claude_code "$version" "$shell" "$nodejs_version"
                ;;
            "reinstall")
                reinstall_claude_code "$version" "$shell" "$nodejs_version"
                ;;
            "uninstall")
                uninstall_claude_code "$version" "$all_flag" "$shell"
                ;;
            "use")
                use_claude_version "$version" "$porcelain" "$nodejs_version"
                ;;
            *)
                log_error "Unknown command: $command"
                log_info "Use --help for usage information"
                exit 1
                ;;
        esac
    ) || return $?
}

main() {
    local parsed_args
    parsed_args=$(parse_arguments "$@")
    
    local validation_result
    if ! validation_result=$(echo "$parsed_args" | validate_arguments 2>&1); then
        # Print validation errors with proper formatting
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                log_error "$line"
            fi
        done <<< "$validation_result"
        log_info "Use --help for usage information"
        return 1
    fi
    
    interpret_arguments "$parsed_args"
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
