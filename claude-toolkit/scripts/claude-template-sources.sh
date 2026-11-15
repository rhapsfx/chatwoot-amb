#!/bin/bash

# Claude Template Sources Management Script
# This script manages template sources (git repositories containing slash commands and subagents)
# Requirements: bash

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

source "$script_dir/library.sh"
source "$script_dir/template-management.sh"

show_help() {
    echo "Claude Template Sources Management Script"
    echo ""
    echo "Usage: claude-template-sources <command> [options]"
    echo ""
    echo "Commands:"
    echo "  add <name> <git-url>           Add a new template source repository"
    echo "  remove <name>                  Remove a template source repository"  
    echo "  list                           List all configured template sources"
    echo ""
    echo "Global Options:"
    echo "  --dry-run                      Preview operation without making system modifications"
    echo "  --debug                        Enable debug output (verbose logging)"
    echo "  --porcelain                    Enable porcelain format (machine-readable output)"
    echo ""
    echo "  --help, -h                     Show this help message"
    echo ""
    echo "Examples:"
    echo "  claude-template-sources add team-alpha git@github.com:myorg/alpha-templates.git"
    echo "  claude-template-sources list                                # List all configured sources"
    echo "  claude-template-sources remove team-alpha                   # Remove source configuration"
}

# Parse command line arguments - pure syntactic parsing, returns key-value pairs
parse_arguments() {
    # Handle global help flag first
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        printf "help\ttrue\n"
        return 0
    fi
    
    # Extract command if provided, or mark as missing
    if [[ $# -eq 0 ]]; then
        printf "no_command\ttrue\n"
        return 0
    fi
    
    local command="$1"
    shift
    printf "command\t%s\n" "$command"
    
    # Separate options from positional arguments
    local positional_args=()
    local remaining_args=("$@")
    
    # First pass: extract all options, leaving positional arguments
    local i=0
    while [[ $i -lt ${#remaining_args[@]} ]]; do
        local arg="${remaining_args[$i]}"
        case "$arg" in
            --dry-run|--porcelain|--debug|--help|-h)
                # Single-flag options - just consume the flag
                ((i++))
                ;;
            --*)
                # Unknown option - consume it
                ((i++))
                ;;
            *)
                # Positional argument - add to array
                positional_args+=("$arg")
                ((i++))
                ;;
        esac
    done
    
    # Store positional arguments for commands that need them
    case "$command" in
        "add")
            if [[ ${#positional_args[@]} -ge 2 ]]; then
                printf "source_name\t%s\n" "${positional_args[0]}"
                printf "git_url\t%s\n" "${positional_args[1]}"
            elif [[ ${#positional_args[@]} -ge 1 ]]; then
                printf "source_name\t%s\n" "${positional_args[0]}"
            fi
            ;;
        "remove")
            if [[ ${#positional_args[@]} -ge 1 ]]; then
                printf "source_name\t%s\n" "${positional_args[0]}"
            fi
            ;;
    esac
    
    # Parse all options syntactically - no validation
    if [[ ${#remaining_args[@]} -gt 0 ]]; then
        for arg in "${remaining_args[@]}"; do
            case "$arg" in
                --dry-run)
                    printf "dry_run\ttrue\n"
                    ;;
                --porcelain)
                    printf "porcelain\ttrue\n"
                    ;;
                --debug)
                    printf "debug\ttrue\n"
                    ;;
                --help|-h)
                    printf "help_after_command\ttrue\n"
                    ;;
                --*)
                    printf "unknown_option\t%s\n" "$arg"
                    ;;
            esac
        done
    fi
}

# Validate parsed arguments for consistency and command-specific requirements
validate_arguments() {
    local command="" 
    local help_requested=false
    local has_no_command=false
    local source_name="" git_url=""

    # Read key-value pairs from stdin and collect validation issues
    while IFS=$'\t' read -r key value; do
        case "$key" in
            command) command="$value" ;;
            source_name) source_name="$value" ;;
            git_url) git_url="$value" ;;
            help) help_requested=true ;;
            no_command) has_no_command=true ;;
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
        printf "%s\n" "Usage: claude-template-sources <command> [options]"
        printf "%s\n" "Commands: add, remove, list"
        return 1
    fi
    
    # Validate command is recognized
    case "$command" in
        add|remove|list)
            ;;
        *)
            printf "Unknown command: %s\n" "$command"
            printf "%s\n" "Valid commands: add, remove, list"
            return 1
            ;;
    esac
    
    # Validate positional arguments for commands that need them
    case "$command" in
        "add")
            if [[ -z "$source_name" ]] || [[ -z "$git_url" ]]; then
                printf "%s\n" "add requires <name> and <git-url> arguments"
                printf "%s\n" "Usage: claude-template-sources add <name> <git-url>"
                return 1
            fi
            ;;
        "remove")
            if [[ -z "$source_name" ]]; then
                printf "%s\n" "remove requires <name> argument"
                printf "%s\n" "Usage: claude-template-sources remove <name>"
                return 1
            fi
            ;;
    esac
    
    # All validations passed
    return 0
}

# Interpret parsed arguments and set variables/perform the work
interpret_arguments() {
    local parsed_args="$1"
    shift
    local command
    local dry_run porcelain debug help_requested
    local source_name="" git_url=""

    # Initialize argument variables with defaults
    command=""
    dry_run="$DRY_RUN"
    porcelain="$PORCELAIN"
    debug="$DEBUG"
    help_requested=false

    # Read and interpret parsed arguments
    while IFS=$'\t' read -r key value; do
        case "$key" in
            help) help_requested=true ;;
            command) command="$value" ;;
            source_name) source_name="$value" ;;
            git_url) git_url="$value" ;;
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

    initialize_claude_toolkit_template_source || exit 1

    case "$command" in
        "add")
            add_template_source "$source_name" "$git_url"
            ;;
        "remove")
            remove_template_source "$source_name"
            ;;
        "list")
            list_template_sources "$porcelain"
            ;;
        *)
            log_error "Unknown command: $command"
            log_info "Use --help for usage information"
            return 1
            ;;
    esac
}

# Main function
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
    
    interpret_arguments "$parsed_args" "$@"
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if ! main "$@"; then
        exit 1
    fi
fi