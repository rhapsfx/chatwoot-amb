#!/bin/bash

# Claude Code Subagents Installation Script
# This script installs Claude Code subagents from the toolkit repository or registered template sources
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
    show_template_help "$TEMPLATE_TYPE_AGENTS" "claude-agents"
}

# Parse command line arguments - pure syntactic parsing, returns key-value pairs
parse_arguments() {
    parse_template_arguments "$@"
}

# Validate parsed arguments for consistency and command-specific requirements
validate_arguments() {
    validate_template_arguments "$TEMPLATE_TYPE_AGENTS"
}


# Main function
main() {
    template_main "$TEMPLATE_TYPE_AGENTS" "$@"
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if ! main "$@"; then
        exit 1
    fi
fi