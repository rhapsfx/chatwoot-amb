#!/bin/bash

# Claude Toolkit Installation Script for macOS and Linux (Enhanced Multi-Shell Support)
# This script installs Claude Toolkit with XDG Base Directory specification compliance
# Requirements: macOS 10.15+, internet connection, git
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

# Symlink-safe way to get parent directory of this script's real directory.
# In many cases it is also git repository directory.
# Can be overridden via environment variable for testing.
script_root_dir="${script_root_dir:-$(dirname -- "$script_dir")}"

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

# Configuration
DEFAULT_REMOTE_REPOSITORY="${DEFAULT_REMOTE_REPOSITORY:-git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git}"
DEFAULT_REMOTE_REPOSITORY_HTTPS="${DEFAULT_REMOTE_REPOSITORY_HTTPS:-https://github.pie.apple.com/AI-for-Devs-Community/claude-toolkit.git}"

get_toolkit_install_dir() {
    printf '%s/claude-toolkit' "$(get_xdg_data_home)"
}

get_toolkit_cache_dir() {
    printf '%s/claude-toolkit' "$(get_xdg_cache_home)"
}

get_default_remote_repository() {
    printf '%s' "$DEFAULT_REMOTE_REPOSITORY"
}

get_default_remote_repository_https() {
    printf '%s' "$DEFAULT_REMOTE_REPOSITORY_HTTPS"
}

# Returns script name for config blocks
get_script_name() {
    printf '%s' "$current_script_name"
}

validate_script() {
    local script_path="$1"

    if [[ ! -f "$script_path" ]]; then
        log_error "File not found: ~${script_path/#$(get_xdg_home)}"
        return 1
    fi

    if [[ ! -x "$script_path" ]]; then
        log_error "File is not executable: ~${script_path/#$(get_xdg_home)}"
        return 1
    fi
}

# Repository validation
validate_repository() {
    local repo_dir="$1"

    log_debug "validate_repository(~${repo_dir/#$(get_xdg_home)})"

    # Check if directory exists and is a git repository
    if [[ ! -d "$repo_dir/.git" ]]; then
        log_error "Not a git repository: ~${repo_dir/#$(get_xdg_home)}"
        return 1
    fi

    # Check git repository state
    if ! git -C "$repo_dir" status >/dev/null 2>&1; then
        log_error "Repository is in invalid state: ~${repo_dir/#$(get_xdg_home)}"
        return 1
    fi

    validate_script "$repo_dir/scripts/claude-toolkit.sh"
    validate_script "$repo_dir/scripts/claude-code.sh"
    validate_script "$repo_dir/scripts/claude-slash.sh"
    validate_script "$repo_dir/scripts/claude-agents.sh"
    validate_script "$repo_dir/scripts/claude-template-sources.sh"

    return 0
}

# Pull repository trying multiple URLs in order
pull_repository() {
    local repo_dir="$1"
    shift
    local urls=("$@")

    log_debug "pull_repository(~${repo_dir/#$(get_xdg_home)}, urls=(${urls[*]}))"

    # Try each URL in order
    local last_error=""
    local attempted_urls=()
    
    for url in "${urls[@]}"; do
        log_debug "Attempting to pull from: $url"
        attempted_urls+=("$url")
        
        # Set remote origin to current URL
        if ! git -C "$repo_dir" remote set-url origin "$url" 2>/dev/null; then
            log_debug "Failed to set remote URL to: $url"
            continue
        fi
        
        # Try to pull from this remote
        if output=$(git -C "$repo_dir" pull 2>&1); then
            log_debug "Successfully pulled from: $url"
            return 0
        fi
        
        last_error="$output"
        log_debug "Pull failed from $url: $last_error"
        
        # Show info about trying next method (if there are more URLs)
        if [[ ${#attempted_urls[@]} -lt ${#urls[@]} ]]; then
            log_info "Pull failed, trying next method..."
        fi
    done

    # All methods failed - report comprehensive error
    log_error "Failed to pull repository using any of the provided URLs"
    for url in "${attempted_urls[@]}"; do
        log_error "Attempted: $url"
    done
    log_error "Last error: $last_error"
    log_info "Please check:"
    log_info "  1. Internet/VPN connectivity"
    log_info "  2. Repository access permissions"
    log_info "  3. SSH key configuration (for SSH URLs)"
    log_info "  4. Authentication credentials (for HTTPS URLs)"
    return 1
}

# Clone repository trying multiple URLs in order
clone_repository() {
    local install_dir="$1"
    shift
    local urls=("$@")

    local parent_dir
    parent_dir="$(dirname -- "$install_dir")"

    log_debug "clone_repository(~${install_dir/#$(get_xdg_home)}, urls=(${urls[*]}))"

    # Create parent directory
    if ! mkdir -p "$parent_dir" 2>/dev/null; then
        log_error "Failed to create directory: ~${parent_dir/#$(get_xdg_home)}"
        log_info "Check file system permissions"
        return 1
    fi

    # Try each URL in order
    local last_error=""
    local attempted_urls=()
    
    for url in "${urls[@]}"; do
        log_debug "Attempting to clone from: $url"
        attempted_urls+=("$url")
        
        if output=$(git clone "$url" "$install_dir" 2>&1); then
            log_debug "Successfully cloned from: $url"
            return 0
        fi
        
        last_error="$output"
        log_debug "Clone failed from $url: $last_error"
        
        # Show info about trying next method (if there are more URLs)
        if [[ ${#attempted_urls[@]} -lt ${#urls[@]} ]]; then
            log_info "Clone failed, trying next method..."
        fi
    done

    # All methods failed - report comprehensive error
    log_error "Failed to clone repository using any of the provided URLs"
    for url in "${attempted_urls[@]}"; do
        log_error "Attempted: $url"
    done
    log_error "Last error: $last_error"
    log_info "Please check:"
    log_info "  1. Internet/VPN connectivity"
    log_info "  2. Repository access permissions"
    log_info "  3. SSH key configuration (for SSH URLs)"
    log_info "  4. Authentication credentials (for HTTPS URLs)"
    return 1
}

reinstall_toolkit() {
    local repository_urls=("$@")

    log_function "reinstall_toolkit(urls=(${repository_urls[*]}))"

    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    log_info "Reinstalling Claude Toolkit..."

    local cache_dir
    cache_dir="$(get_toolkit_cache_dir)"

    # Use first repository URL for hash calculation to maintain consistency
    local repo_hash
    repo_hash="$(printf '%s' "${repository_urls[0]}" | compute_checksum)"

    local cached_reinstall_dir
    cached_reinstall_dir="$cache_dir/$repo_hash/reinstall"

    mkdir -p "$cached_reinstall_dir"

    cp "$current_script_file" "$cached_reinstall_dir"
    cp "$script_dir/library.sh" "$cached_reinstall_dir"

    # Create comma-separated URL list for --remote-repository
    local url_list
    url_list=$(IFS=','; echo "${repository_urls[*]}")
    
    exec "$cached_reinstall_dir/$current_script_name" _reinstall --remote-repository "$url_list"
}

create_script_symlink() {
    local install_dir="$1"
    local bin_dir="$2"
    local script_name="$3"

    local bin_dir_parent
    bin_dir_parent="$(dirname -- "$bin_dir")"

    local script_rel_path
    script_rel_path="..${install_dir/#$bin_dir_parent}/scripts/$script_name"

    local symlink_name
    symlink_name="${script_name%.sh}"

    log_info "Creating symlink for $script_name..."
    create_atomic_symlink "$bin_dir/$symlink_name" "$script_rel_path"
}

install_toolkit() {
    # Parse arguments: URLs are passed first, then -- separator, then other args
    local repository_urls=()
    local target_shell=""
    
    # Collect URLs until we hit the -- separator
    while [[ $# -gt 0 ]] && [[ "$1" != "--" ]]; do
        repository_urls+=("$1")
        shift
    done
    
    # Skip the -- separator
    if [[ "$1" == "--" ]]; then
        shift
    fi
    
    # Get remaining arguments
    target_shell="$1"

    log_function "install_toolkit(urls=(${repository_urls[*]}), shell=$target_shell)"

    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    log_info "Installing Claude Toolkit..."

    local install_dir
    install_dir="$(get_toolkit_install_dir)"

    # Step 1: Check if repository already exists
    if [[ -d "$install_dir/.git" ]]; then
        # Repository exists - validate it
        if ! output=$(validate_repository "$install_dir" 2>&1); then
            log_error "Repository at ~${install_dir/#$(get_xdg_home)} is invalid or corrupted"
            log_error "$output"
            reinstall_toolkit "${repository_urls[@]}"
            # reinstall_toolkit never returns because of exec
        fi
        log_warning "Claude Toolkit is already installed"
        log_info "If you want to update Claude Toolkit, invoke \`claude-toolkit update\`."
        return 0
    fi

    # Step 2: Clone repository if absent
    log_info "Cloning Claude Toolkit repository..."
    if validate_repository "$script_root_dir"; then
        # Trick: we clone from already valid current repository and then update remote.
        clone_repository "$install_dir" "$script_root_dir"
        
        # Optimize URL list by adding current remote URL as first element
        local optimized_urls=()
        local current_remote_url
        if current_remote_url=$(git -C "$script_root_dir" remote get-url origin 2>/dev/null); then
            optimized_urls+=("$current_remote_url")
        fi
        optimized_urls+=("${repository_urls[@]}")
        
        # Use pull_repository to try multiple URLs
        pull_repository "$install_dir" "${optimized_urls[@]}"
    else
        # Full clone from remote repository
        clone_repository "$install_dir" "${repository_urls[@]}"
    fi

    local bin_dir
    bin_dir="$(get_xdg_bin_dir)"

    create_script_symlink "$install_dir" "$bin_dir" "claude-toolkit.sh"
    create_script_symlink "$install_dir" "$bin_dir" "claude-code.sh"
    create_script_symlink "$install_dir" "$bin_dir" "claude-slash.sh"
    create_script_symlink "$install_dir" "$bin_dir" "claude-agents.sh"
    create_script_symlink "$install_dir" "$bin_dir" "claude-template-sources.sh"

    update_shell_configs "$target_shell"

    # Step 6: Show success information
    log_success "Claude Toolkit installed"

    validate_toolkit

    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo ""
    echo "  1. Restart your shell or run:"
    echo "     exec \$SHELL -l"
    echo ""
    echo "  2. Verify installation:"
    echo "     claude-toolkit --help"
    echo ""
    echo "  3. Basic usage:"
    echo "     claude-code install      # Install Claude Code"
    echo "     claude-code list         # List available Claude Code versions"
    echo "     claude-slash install     # Install slash commands"
    echo "     claude-slash list        # List slash commands"
    echo "     claude-agents install    # Install subagents"
    echo "     claude-agents list       # List subagents"
    echo "     claude-template-sources add <name> <url>  # Add template source"
    echo "     claude-template-sources list              # List template sources"
    echo ""

    return 0
}

remove_script_symlink() {
    local bin_dir="$1"
    local symlink_name="$2"
    if [[ -L "$bin_dir/$symlink_name" ]]; then
        log_info "Removing $symlink_name symlink..."
        rm -f "$bin_dir/$symlink_name"
    fi
}

uninstall_toolkit() {
    local yes_flag="$1"
    local target_shell="${2:-}"

    log_function "uninstall_toolkit"
    log_info "Uninstalling Claude Toolkit..."

    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    log_info "Uninstalling Claude Toolkit..."

    local install_dir
    install_dir="$(get_toolkit_install_dir)"

    local bin_dir
    bin_dir="$(get_xdg_bin_dir)"

    if [[ ! -d "$install_dir" ]] && [[ ! -L "$bin_dir/claude-code" ]] && [[ ! -L "$bin_dir/claude-slash" ]] && [[ ! -L "$bin_dir/claude-template-sources" ]]; then
        log_warning "Claude Toolkit is not installed, so there's nothing to uninstall"
        return 0
    fi

    if [[ "$yes_flag" != true ]]; then
        log_warning "This will remove Claude Toolkit from your system."
        printf "Proceed with uninstall? [y/N]: " >&2
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Uninstall cancelled by user"
            return 1
        fi
        log_info "Proceeding with uninstall"
    fi

    remove_script_symlink "$bin_dir" "claude-toolkit"
    remove_script_symlink "$bin_dir" "claude-code"
    remove_script_symlink "$bin_dir" "claude-slash"
    remove_script_symlink "$bin_dir" "claude-agents"
    remove_script_symlink "$bin_dir" "claude-template-sources"

    if [[ -d "$install_dir" ]]; then
        log_info "Removing local repository..."
        rm -rf "$install_dir"
    fi

    cleanup_shell_configurations "$target_shell"

    log_success "Claude Toolkit uninstalled"
    return 0
}

update_toolkit() {
    local repository_urls=("$@")

    log_function "update_toolkit(urls=(${repository_urls[*]}))"

    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    log_info "Updating Claude Toolkit..."

    local install_dir
    install_dir="$(get_toolkit_install_dir)"

    # Step 2: Validate repository state
    if ! output=$(validate_repository "$install_dir" 2>&1); then
        log_error "Repository at ~${install_dir/#$(get_xdg_home)} is invalid or corrupted"
        log_error "$output"
        reinstall_toolkit "${repository_urls[@]}"
        # reinstall_toolkit never returns because of exec
    fi

    # Step 3: Perform git pull
    log_debug "git -C \"$install_dir\" pull"
    output=$(git -C "$install_dir" pull 2>&1) || { log_error "$output"; return 1; }

    log_success "Claude Toolkit updated"

    # Step 4: Validate updated repository
    # We need to replace current shell, because updated script may implement different validation.
    exec "$install_dir/scripts/$current_script_name" validate
}

validate_toolkit() {
    log_function "validate_toolkit"

    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    log_info "Validating Claude Toolkit..."

    local install_dir
    install_dir="$(get_toolkit_install_dir)"

    if ! output=$(validate_repository "$install_dir" 2>&1); then
        log_error "Repository at ~${install_dir/#$(get_xdg_home)} is invalid or corrupted"
        log_error "$output"
        log_info "Please run \`claude-toolkit reinstall\` to fully reinstall it"
        return 1
    fi

    log_success "Claude Toolkit validated, everything looks OK"
}

_reinstall_toolkit() {
    local repository_urls=("$@")

    local install_dir
    install_dir="$(get_toolkit_install_dir)"

    local cache_dir
    cache_dir="$(get_toolkit_cache_dir)"

    # Use first repository URL for hash calculation to maintain consistency
    local repo_hash
    repo_hash="$(printf '%s' "${repository_urls[0]}" | compute_checksum)"

    local cached_reinstall_dir
    cached_reinstall_dir="$cache_dir/$repo_hash/reinstall"

    if [[ $(resolve_all "$script_dir") != $(resolve_all "$cached_reinstall_dir") ]]; then
        log_error "_reinstall must be invoked only in directory $cached_reinstall_dir"
        return 1
    fi

    uninstall_toolkit true

    local cached_install_dir
    cached_install_dir="$cache_dir/$repo_hash/install"

    if [[ -d "$cached_install_dir" ]]; then
        log_debug "rm -rf -- \"$cached_install_dir\""
        rm -rf -- "$cached_install_dir"
    fi

    log_info "Cloning Claude Toolkit repository into cache directory"
    clone_repository "$cached_install_dir" "${repository_urls[@]}"

    # Create comma-separated URL list for --remote-repository
    local url_list
    url_list=$(IFS=','; echo "${repository_urls[*]}")
    
    exec "$cached_install_dir/scripts/$current_script_name" install --remote-repository "$url_list"
}

# Parse command line arguments - pure syntactic parsing, returns key-value pairs
parse_arguments() {
    # Handle global help flag first
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        printf "help\\ttrue\\n"
        return 0
    fi

    # Extract command if provided, or mark as missing
    if [[ $# -eq 0 ]]; then
        printf "no_command\\ttrue\\n"
    else
        local command="$1"
        shift
        printf "command\\t%s\\n" "$command"
    fi

    # Parse all options syntactically - no validation
    while [[ $# -gt 0 ]]; do
        case $1 in
            --shell)
                if [[ -n "${2:-}" ]] && [[ "$2" != --* ]]; then
                    printf "shell\\t%s\\n" "$2"
                    shift 2
                else
                    printf "shell_no_value\\ttrue\\n"
                    shift
                fi
                ;;
            --shell=*)
                printf "shell\\t%s\\n" "${1#*=}"
                shift
                ;;
            --remote-repository)
                if [[ -n "${2:-}" ]] && [[ "$2" != --* ]]; then
                    printf "remote_repository\\t%s\\n" "$2"
                    shift 2
                else
                    printf "remote_repository_no_value\\ttrue\\n"
                    shift
                fi
                ;;
            --remote-repository=*)
                printf "remote_repository\\t%s\\n" "${1#*=}"
                shift
                ;;
            --https)
                printf "https\\ttrue\\n"
                shift
                ;;
            --dry-run)
                printf "dry_run\\ttrue\\n"
                shift
                ;;
            --debug)
                printf "debug\\ttrue\\n"
                shift
                ;;
            --yes|-y|--force)
                printf "yes\\ttrue\\n"
                shift
                ;;
            --help|-h)
                printf "help_after_command\\ttrue\\n"
                shift
                ;;
            *)
                printf "unknown_option\\t%s\\n" "$1"
                shift
                ;;
        esac
    done
}

# Validate parsed arguments for consistency and command-specific requirements
validate_arguments() {
    local command="" shell="" use_https=false
    local help_requested=false

    # Read key-value pairs from stdin and collect validation issues
    while IFS=$'\t' read -r key value; do
        # echo "DEBUG: Processing key='$key' value='$value'" >&2
        case "$key" in
            command) command="$value" ;;
            shell) shell="$value" ;;
            https) use_https=true ;;
            help) help_requested=true ;;
            no_command) command=install ;;
            shell_no_value)
                printf "%s\n" "--shell requires a value"
                return 1
                ;;
            remote_repository_no_value)
                printf "%s\n" "--remote-repository requires a value"
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

    # Validate command is recognized
    case "$command" in
        install|reinstall|uninstall|update|validate|_reinstall)
            ;;
        *)
            printf "Unknown command: %s\n" "$command"
            printf "%s\n" "Valid commands: install, uninstall, update"
            return 1
            ;;
    esac

    # Validate shell if specified
    if [[ -n "$shell" ]]; then
        case "$shell" in
            bash|zsh|fish)
                ;;
            *)
                printf "Unsupported shell: %s (supported: bash, zsh, fish)\\n" "$shell"
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
    local command shell remote_repository use_https dry_run debug yes_flag help_requested

    # Initialize argument variables with defaults
    command=""
    shell=""
    remote_repository=""
    use_https=false
    dry_run="$DRY_RUN"
    debug="$DEBUG"
    yes_flag=false
    help_requested=false

    # Read and interpret parsed arguments
    while IFS=$'\t' read -r key value; do
        case "$key" in
            help) help_requested=true ;;
            command) command="$value" ;;
            shell) shell="$value" ;;
            remote_repository) remote_repository="$value" ;;
            https) use_https=true ;;
            dry_run) dry_run=true ;;
            debug) debug=true ;;
            yes) yes_flag=true ;;
        esac
    done <<< "$parsed_args"

    # Handle help request
    if [[ "$help_requested" == true ]]; then
        show_help
        exit 0
    fi

    # Set default operation if none specified and inform user
    if [[ -z "$command" ]]; then
        command="install"
        log_info "No command specified, defaulting to install"
    fi

    # Set global environment variables for functions that need them
    DEBUG="$debug"
    DRY_RUN="$dry_run"

    if [[ "$debug" == true ]]; then
        log_info "Debug mode enabled"
    fi

    # Build repository URL list based on user preferences
    local repository_urls=()
    if [[ -n "$remote_repository" ]]; then
        # User specified --remote-repository, parse comma-separated URLs
        IFS=',' read -ra repository_urls <<< "$remote_repository"
        # Trim whitespace from each URL
        for i in "${!repository_urls[@]}"; do
            repository_urls[i]="${repository_urls[i]// /}"  # Remove all spaces
        done
        log_debug "Using user-specified repository URLs: ${repository_urls[*]}"
    else
        # User did not specify repository, build list based on --https preference
        local ssh_url https_url
        ssh_url="$(get_default_remote_repository)"
        https_url="$(get_default_remote_repository_https)"
        
        if [[ "$use_https" == true ]]; then
            # HTTPS preferred: try HTTPS first, then SSH
            repository_urls=("$https_url" "$ssh_url")
            log_debug "Using HTTPS-first repository URLs: $https_url, $ssh_url"
        else
            # SSH preferred (default): try SSH first, then HTTPS
            repository_urls=("$ssh_url" "$https_url")
            log_debug "Using SSH-first repository URLs: $ssh_url, $https_url"
        fi
    fi

    log_debug "command=$command"
    log_debug "shell=$shell"
    log_debug "dry_run=$dry_run"
    log_debug "use_https=$use_https"
    log_debug "repository_urls=(${repository_urls[*]})"

    # Run main logic in subshell to isolate traps
    (
        case "$command" in
            "install")
                install_toolkit "${repository_urls[@]}" -- "$shell"
                ;;
            "reinstall")
                reinstall_toolkit "${repository_urls[@]}"
                ;;
            "uninstall")
                uninstall_toolkit "$yes_flag" "$shell"
                ;;
            "update")
                update_toolkit "${repository_urls[@]}"
                ;;
            "validate")
                validate_toolkit
                ;;
            "_reinstall")
                _reinstall_toolkit "${repository_urls[@]}"
                ;;
            *)
                log_error "Unknown command: $command"
                log_info "Use --help for usage information"
                exit 1
                ;;
        esac
    ) || return $?
}

show_help() {
    echo "Claude Toolkit Setup Script"
    echo ""
    echo "Usage: claude-toolkit <command> [options]"
    echo ""
    echo "Commands:"
    echo "  install                Install Claude Toolkit (default command)"
    echo "  reinstall              Reinstall Claude Toolkit"
    echo "  uninstall              Remove Claude Toolkit installation"
    echo "  validate               Validate Claude Toolkit installation"
    echo "  update                 Update Claude Toolkit from remote repository"
    echo ""
    echo "Options:"
    echo "  --shell <shell>        Target specific shell (bash, zsh, fish)"
    echo "  --https                Use HTTPS git URLs instead of SSH (default: SSH)"
    echo "  --dry-run              Print function names without executing"
    echo "  --debug                Enable debug output"
    echo "  --yes, -y, --force     Skip confirmation prompts (auto-accept)"
    echo "  --help, -h             Show this help message"
    echo ""
    echo "Examples:"
    echo "  claude-toolkit                     # Install Claude Toolkit (default)"
    echo "  claude-toolkit install             # Install Claude Toolkit (explicit)"
    echo "  claude-toolkit install --shell=zsh # Install for zsh only"
    echo "  claude-toolkit install --https     # Install using HTTPS URLs"
    echo "  claude-toolkit uninstall           # Remove Claude Toolkit"
    echo "  claude-toolkit update              # Update Claude Toolkit"
    echo ""
    echo "Supported shells: bash, zsh, fish"
    echo "Installation follows XDG Base Directory specification"
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
