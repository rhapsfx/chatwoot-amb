#!/bin/bash

# Claude Toolkit Library

# Execution flags
DEBUG="${DEBUG:-false}"
DRY_RUN="${DRY_RUN:-false}"
PORCELAIN="${PORCELAIN:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GRAY='\033[2m'
NC='\033[0m' # No Color

# Core logger: _log LEVEL COLOR... ARGS...
_log() {
  local level="$1" color="${2:-}" reset="${NC:-}"
  shift 2
  # Join all remaining args with spaces into one message
  local msg="$*"
  if [[ -n "$color" ]]; then
    printf '%b[%s] %s%b\n' "$color" "$level" "$msg" "$reset" >&2
  else
    printf '[%s] %s\n' "$level" "$msg" >&2
  fi
}

# Logging functions
log_info()    { _log "INFO"    ""            "$@"; }
log_success() { _log "SUCCESS" "${GREEN:-}"   "$@"; }
log_warning() { _log "WARNING" "${YELLOW:-}"  "$@"; }
log_error()   { _log "ERROR"   "${RED:-}"     "$@"; }

log_debug() {
  if [[ "${DEBUG:-false}" == true ]]; then
    _log "DEBUG" "${GRAY:-}" "$@"
  fi
}

log_function() {
  if [[ "${DRY_RUN:-false}" == true ]]; then
    # Concatenate "dryrun:" with the function arguments directly
    log_info "dryrun:$*"
    return 0
  fi
  log_debug "$@"
}

# get_xdg_home - Returns XDG home directory (custom extension for sandbox testing)
get_xdg_home() {
    printf '%s' "${XDG_HOME:-$HOME}"
}

# get_xdg_data_home - Returns XDG data directory ($XDG_DATA_HOME or ~/.local/share)
get_xdg_data_home() {
    if [[ -n "${XDG_DATA_HOME:-}" ]]; then
        printf '%s' "$XDG_DATA_HOME"
    else
        printf '%s/.local/share' "$(get_xdg_home)"
    fi
}

# get_xdg_cache_home - Returns XDG cache directory ($XDG_CACHE_HOME or ~/.cache)
get_xdg_cache_home() {
    if [[ -n "${XDG_CACHE_HOME:-}" ]]; then
        printf '%s' "$XDG_CACHE_HOME"
    else
        printf '%s/.cache' "$(get_xdg_home)"
    fi
}

# get_xdg_config_home - Returns XDG config directory ($XDG_CONFIG_HOME or ~/.config)
get_xdg_config_home() {
    if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
        printf '%s' "$XDG_CONFIG_HOME"
    else
        printf '%s/.config' "$(get_xdg_home)"
    fi
}

# get_xdg_bin_dir - Returns XDG bin directory ($XDG_BIN_DIR or ~/.local/bin)
get_xdg_bin_dir() {
    if [[ -n "${XDG_BIN_DIR:-}" ]]; then
        printf '%s' "$XDG_BIN_DIR"
    else
        printf '%s/.local/bin' "$(get_xdg_home)"
    fi
}

# get_zdotdir - Returns zsh dotfiles directory ($ZDOTDIR or home directory)
get_zdotdir() {
    if [[ -n "${ZDOTDIR:-}" ]]; then
        printf '%s' "$ZDOTDIR"
    else
        printf '%s' "$(get_xdg_home)"
    fi
}

compute_checksum() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | cut -d' ' -f1
  elif command -v sha1sum >/dev/null 2>&1; then
    sha1sum | cut -d' ' -f1
  elif command -v md5sum >/dev/null 2>&1; then
    md5sum | cut -d' ' -f1
  else
    log_error 'No checksum tool available'
    return 1
  fi
}

compute_file_checksum() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        compute_checksum < "$file_path"
    fi
}

# get_os_type - Returns OS type (Darwin, Linux)
get_os_type() {
    uname
}

# get_os_name - Returns friendly OS name (macOS, Linux)
get_os_name() {
    case "$(get_os_type)" in
        Darwin) echo "macOS" ;;
        Linux) echo "Linux" ;;
        *) get_os_type ;;
    esac
}

# get_architecture - Returns normalized architecture name for downloads
get_architecture() {
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        x86_64|amd64) echo "x64" ;;
        aarch64|arm64) echo "arm64" ;;
        *) echo "$arch" ;;
    esac
}

# get_platform - Returns platform identifier (was get_node_platform)
get_platform() {
    case "$(get_os_type)" in
        Darwin) echo "darwin" ;;
        Linux) echo "linux" ;;
        *) 
            log_error "Unsupported OS: $(get_os_type)"
            return 1
            ;;
    esac
}

# Extract base names from file paths
# Reads file paths from stdin, outputs base names to stdout
get_file_base_names() {
    while IFS= read -r file_path; do
        [[ -n "$file_path" ]] || continue
        basename "$file_path"
    done
}

# is_mode_readonly - Check if file/directory has read-only permissions by mode bits
#
# Returns:
#   0 - File is read-only (no write bits set for owner, group, or other)
#   1 - File has write permissions somewhere
#   2 - Unable to determine file mode (stat command failed)
#
# This function examines the actual permission mode bits (e.g., 0444, 0555) rather than
# testing runtime write access. It's useful for safety checks before file operations,
# independent of current user privileges or ACLs.
#
# Examples:
#   chmod 444 file.txt && is_mode_readonly file.txt  # returns 0 (read-only)
#   chmod 644 file.txt && is_mode_readonly file.txt  # returns 1 (writable)
is_mode_readonly() {
    local file_path="$1"
    local mode_octal

    # Get octal mode using platform-appropriate stat command
    if mode_octal=$(stat -c '%a' -- "$file_path" 2>/dev/null); then
        # GNU stat (Linux)
        :
    elif mode_octal=$(stat -f '%Lp' -- "$file_path" 2>/dev/null); then
        # BSD stat (macOS)
        :
    else
        # stat command failed - file doesn't exist or no permissions to stat
        return 2
    fi

    # Check if no write bits are set (owner=200, group=020, other=002)
    # 0222 in octal = 146 in decimal = write permissions for all
    (( (8#$mode_octal & 0222) == 0 ))
}

# resolve_all PATH -> prints canonical absolute path with all symlinks resolved
resolve_all() {
  local p="$1" dir base target

  # start absolute
  [[ $p != /* ]] && p="$PWD/$p"

  # normalize . and .. in a loop while resolving links
  while :; do
    # collapse /./
    p=${p//\/.\//\/}
    # collapse trailing /.
    [[ $p == */. ]] && p=${p%/.}

    # handle trailing .. cheaply
    while [[ $p == */.. ]]; do p="$(dirname "$(dirname "$p")")"; done

    # if the whole path is a symlink, resolve it
    if [[ -L $p ]]; then
      target=$(readlink "$p") || return 1
      [[ $target != /* ]] && p="$(dirname "$p")/$target" || p="$target"
      continue
    fi

    # otherwise, resolve symlinks in the directory part
    dir=$(dirname -- "$p")
    base=$(basename -- "$p")
    dir=$(cd -P -- "$dir" && pwd -P) || return 1
    p="$dir/$base"

    # done if final is not a symlink
    [[ -L $p ]] || { printf '%s\n' "$p"; return 0; }
    # if final is a link, loop again to resolve it
    target=$(readlink "$p") || return 1
    [[ $target != /* ]] && p="$(dirname "$p")/$target" || p="$target"
  done
}

# create_atomic_symlink - Atomically creates or replaces a symlink using temporary files for rollback safety
create_atomic_symlink() {
    if [[ $# -ne 2 ]]; then
        log_error "create_atomic_symlink: exactly two arguments required (symlink_path, target_path)"
        return 2
    fi
    local symlink_path="$1"
    local target_path="$2"

    if [[ -z "$target_path" ]]; then
        log_error "Target path must not be empty"
        return 2
    fi
    if [[ -z "$symlink_path" ]]; then
        log_error "Symlink path must not be empty"
        return 2
    fi

    log_debug "create_atomic_symlink($symlink_path, $target_path)"

    local symlink_parent
    symlink_parent="$(dirname "$symlink_path")"

    # Ensure parent dir exists
    mkdir -p "$symlink_parent"

    # temp_new: unique placeholder for the new symlink (same dir for atomic rename)
    local temp_new
    if ! temp_new="$(mktemp "$symlink_parent/$(basename "$symlink_path").new.XXXXXX" 2>/dev/null)"; then
        log_error "Failed to create temporary placeholder in: ~${symlink_parent/#$(get_xdg_home)}"
        return 1
    fi
    rm -f "$temp_new"
    if ! ln -s "$target_path" "$temp_new" 2>/dev/null; then
        log_error "Failed to create temporary symlink: ~${temp_new/#$(get_xdg_home)} -> $target_path"
        rm -f "$temp_new" 2>/dev/null
        return 1
    fi

    # temp_old: backup of existing symlink (if any)
    local temp_old=""
    if [[ -e "$symlink_path" || -L "$symlink_path" ]]; then
        if ! temp_old="$(mktemp "$symlink_parent/$(basename "$symlink_path").old.XXXXXX" 2>/dev/null)"; then
            log_error "Failed to create temporary backup in: ~${symlink_parent/#$(get_xdg_home)}"
            rm -f "$temp_new" 2>/dev/null
            return 1
        fi
        rm -f "$temp_old"
        # Rename symlink -> temp_old (rename of the symlink itself; not followed)
        if ! mv -f "$symlink_path" "$temp_old" 2>/dev/null; then
            log_error "Failed to back up existing symlink: ~${symlink_path/#$(get_xdg_home)}"
            rm -f "$temp_new" "$temp_old" 2>/dev/null
            return 1
        fi
    fi

    # Promote temp_new -> symlink_path
    if ! mv -f "$temp_new" "$symlink_path" 2>/dev/null; then
        log_error "Failed to activate new symlink: ~${symlink_path/#$(get_xdg_home)}"
        # Roll back if we have a backup
        if [[ -n "$temp_old" && -e "$temp_old" ]]; then
            mv -f "$temp_old" "$symlink_path" 2>/dev/null || {
                log_error "Rollback failed; manual repair needed: ~${symlink_path/#$(get_xdg_home)}"
            }
        fi
        rm -f "$temp_new" 2>/dev/null
        return 1
    fi

    # Success: drop backup
    [[ -n "$temp_old" ]] && rm -f "$temp_old" 2>/dev/null

    return 0
}

# detect_available_shells - Lists available shells from predefined set (bash, zsh, fish)
detect_available_shells() {
    local found=0
    for sh in bash zsh fish; do
        if command -v "$sh" >/dev/null 2>&1; then
            printf '%s\n' "$sh"
            found=1
        fi
    done
    [[ $found -eq 1 ]] || return 1
}

# get_shell_config_file - Returns config file path for shell (handles bash/zsh/fish, respects ZDOTDIR)
get_shell_config_file() {
    if [[ $# -ne 1 || -z "${1:-}" ]]; then
        log_error "get_shell_config_file: exactly one non-empty shell name required"
        return 2
    fi

    local target_shell="$1"
    local home_dir
    home_dir="$(get_xdg_home)"

    case "$target_shell" in
        fish)
            local config_home
            config_home="$(get_xdg_config_home)" || return 1
            printf '%s/fish/config.fish' "$config_home"
            ;;
        zsh)
            local zdotdir
            zdotdir="$(get_zdotdir)" || return 1
            printf '%s/.zshrc' "$zdotdir"
            ;;
        bash)
            local os
            os="$(uname 2>/dev/null || printf 'Unknown')"
            if [[ "$os" == "Darwin" ]]; then
                printf '%s/.bash_profile' "$home_dir"
            else
                printf '%s/.bashrc' "$home_dir"
            fi
            ;;
        *)
            log_error "Unsupported shell: $target_shell"
            return 1
            ;;
    esac
}

# config_block_exists - Tests if config block with prefix exists in file
config_block_exists() {
    local config_file="$1"
    local marker_prefix="$2"
    local marker_start="# >>> $marker_prefix start >>>"

    [[ -f "$config_file" ]] && grep -F "$marker_start" "$config_file" >/dev/null 2>&1
}

# remove_config_block - Removes config blocks by prefix (handles multiple blocks in single awk pass)
remove_config_block() {
    local config_file="$1"
    local marker_prefix="$2"

    log_debug "remove_config_block(~${config_file/#$(get_xdg_home)}, $marker_prefix)"

    if ! config_block_exists "$config_file" "$marker_prefix"; then
        log_debug "remove_config_block: No $marker_prefix configuration found in ~${config_file/#$(get_xdg_home)}"
        return 0
    fi

    local marker_start="# >>> $marker_prefix start >>>"
    local marker_end="# <<< $marker_prefix end <<<"

    # Find all complete block pairs and remove them in a single awk pass
    # This replicates the old behavior: only remove blocks that have both start and end markers
    local tmpfile
    tmpfile=$(mktemp)

    # Get all start and end line numbers
    local start_lines end_lines
    start_lines=$(grep -n -F "$marker_start" "$config_file" | cut -d: -f1)
    end_lines=$(grep -n -F "$marker_end" "$config_file" | cut -d: -f1)

    if [[ -z "$start_lines" ]]; then
        # No start markers found, nothing to remove
        rm -f "$tmpfile"
        return 0
    fi

    # Build awk script to remove complete blocks only
    local awk_conditions=""
    local removed_any=false

    while IFS= read -r start_line; do
        [[ -z "$start_line" ]] && continue

        # Find the first end marker after this start marker
        local matching_end=""
        while IFS= read -r end_line; do
            [[ -z "$end_line" ]] && continue
            if [[ "$end_line" -gt "$start_line" ]]; then
                matching_end="$end_line"
                break
            fi
        done <<< "$end_lines"

        if [[ -n "$matching_end" ]]; then
            # Found complete block - add to removal conditions
            if [[ -n "$awk_conditions" ]]; then
                awk_conditions="$awk_conditions || "
            fi
            awk_conditions="$awk_conditions(NR >= $start_line && NR <= $matching_end)"
            removed_any=true
        fi
    done <<< "$start_lines"

    if [[ "$removed_any" == true ]]; then
        # Use awk to remove all identified complete blocks in one pass
        awk "!($awk_conditions)" "$config_file" > "$tmpfile"
        mv -f "$tmpfile" "$config_file"
        log_info "Removed $marker_prefix configuration from ~${config_file/#$(get_xdg_home)}"
    else
        rm -f "$tmpfile"
        log_debug "remove_config_block: No complete blocks found to remove in ~${config_file/#$(get_xdg_home)}"
    fi

    return 0
}

# ensure_config_file_exists - Creates config file and parent directories if needed
ensure_config_file_exists() {
    local config_file="$1"
    if [[ ! -f "$config_file" ]]; then
        mkdir -p "$(dirname "$config_file")"
        touch "$config_file"
    fi
}

# add_config_block - Adds config block with markers (removes existing block first)
add_config_block() {
    local config_file="$1"
    local marker_prefix="$2"
    local content="$3"

    ensure_config_file_exists "$config_file"

    # Remove existing block first
    remove_config_block "$config_file" "$marker_prefix"

    # Add new block
    local marker_start="# >>> $marker_prefix start >>>"
    local marker_end="# <<< $marker_prefix end <<<"

    {
        printf "%s\n" "$marker_start"
        printf "%s" "$content"
        printf "\n%s\n" "$marker_end"
    } >> "$config_file"
}

# get_script_name - Returns script name for config blocks
get_script_name() {
    printf 'get_script_name must be overridden is consuming scripts\n' >&2
    return 1
}

# remove_shell_config - Removes shell config for specific shell
remove_shell_config() {
    local target_shell="$1"
    local config_file
    config_file=$(get_shell_config_file "$target_shell")
    remove_config_block "$config_file" "$(get_script_name)"
}

# remove_shell_configs - Removes configs for multiple shells from stdin
remove_shell_configs() {
    while read -r target_shell; do
        [[ -z "$target_shell" ]] && continue
        remove_shell_config "$target_shell"
    done
}

# generate_shell_config - Generates Claude Code shell configuration (currently minimal placeholder)
generate_shell_config() {
    local script_name="$1"
    # shellcheck disable=SC2034
    local target_shell="$2"
    printf '# environment for %s\n' "$script_name"
}

# Update shell configuration for Claude Code
update_shell_config() {
    local target_shell="$1"

    log_debug "update_shell_config($target_shell)"

    local config_file
    config_file=$(get_shell_config_file "$target_shell")

    log_debug "update_shell_config: config_file=~${config_file/#$(get_xdg_home)}"

    # Add or update Claude Code configuration
    log_debug "update_shell_config: generating $(get_script_name) configuration"
    local content
    content=$(generate_shell_config "$(get_script_name)" "$target_shell")

    log_debug "update_shell_config: adding $(get_script_name) configuration to config file"

    local add_config_block_output

    if ! add_config_block_output=$(add_config_block "$config_file" "$(get_script_name)" "$content"); then
        log_error "Failed to add config block to ~${config_file/#$(get_xdg_home)}"
        log_error "$add_config_block_output"
        return 1
    fi
}

update_shell_configs() {
    local target_shell="$1"

    log_debug "update_shell_configs($target_shell)"
    log_info "Updating shell configs..."

    if [[ -n "$target_shell" ]]; then
        log_debug "update_shell_configs: Configuring specified shell: $target_shell"
        update_xdg_path_config "$target_shell"
        update_shell_config "$target_shell"
    else
        # Detect shells once and reuse the output
        local available_shells
        available_shells="$(detect_available_shells)"
        local shells_count
        shells_count=$(echo "$available_shells" | wc -l)

        if [[ $shells_count -eq 0 ]]; then
            log_error "No supported shells found (bash, zsh, fish)"
            exit 1
        fi

        log_debug "Auto-detected shells:"
        echo "$available_shells" | while read -r target_shell; do
            [[ -z "$target_shell" ]] && continue
            log_debug "  $target_shell"
        done

        echo "$available_shells" | while read -r target_shell; do
            [[ -z "$target_shell" ]] && continue
            update_xdg_path_config "$target_shell"
            update_shell_config "$target_shell"
        done
    fi

    # Export for current session
    export PATH="$(get_xdg_bin_dir):$PATH"
}

# cleanup_shell_configurations - Removes configs for specified shell or all detected shells
cleanup_shell_configurations() {
    local target_shell="$1"

    log_debug "cleanup_shell_configurations($target_shell)"

    if [[ -n "$target_shell" ]]; then
        log_debug "cleanup_shell_configurations: Cleaning configuration for specified shell: $target_shell"
        # Remove only script-specific config, keep XDG path config (shared by other applications)
        remove_shell_config "$target_shell"
    else
        local available_shells
        available_shells="$(detect_available_shells)"

        if [[ -z "$available_shells" ]]; then
            log_debug "cleanup_shell_configurations: No shells detected for cleanup"
        else
            echo "$available_shells" | while read -r shell; do
                [[ -z "$shell" ]] && continue
                remove_shell_config "$shell"
            done

            local shells_count
            shells_count=$(echo "$available_shells" | wc -l | tr -d ' ')
            log_debug "cleanup_shell_configurations: Cleaned configuration for $shells_count detected shells"
        fi
    fi
}

# generate_xdg_path_config - Generates shell-specific XDG PATH configuration
generate_xdg_path_config() {
    local target_shell="$1"

    case "$target_shell" in
        fish)
            printf "# XDG user executables directory\n"
            printf "if set -q XDG_BIN_DIR\n"
            printf "    set -gx PATH \"\$XDG_BIN_DIR\" \$PATH\n"
            printf "else\n"
            printf "    set -gx PATH \"\$HOME/.local/bin\" \$PATH\n"
            printf "end\n"
            ;;
        zsh|bash)
            printf "# XDG user executables directory\n"
            printf "export PATH=\"\${XDG_BIN_DIR:-\$HOME/.local/bin}:\$PATH\"\n"
            ;;
    esac
}

# Update XDG PATH configuration
update_xdg_path_config() {
    local target_shell="$1"
    local config_file
    config_file=$(get_shell_config_file "$target_shell")

    log_debug "update_xdg_path_config(~${config_file/#$(get_xdg_home)})"

    # Check if XDG PATH already configured
    if config_block_exists "$config_file" "xdg-user-bin"; then
        log_debug "update_xdg_path_config: XDG PATH already configured in config file"
        return 0
    fi

    # Add XDG PATH configuration
    log_debug "update_xdg_path_config: generating XDG PATH configuration"
    local content
    content=$(generate_xdg_path_config "$target_shell")

    log_debug "update_xdg_path_config: adding XDG PATH configuration to config file"

    local add_config_block_output

    if ! add_config_block_output=$(add_config_block "$config_file" "xdg-user-bin" "$content"); then
        log_error "Failed to add config block to ~${config_file/#$(get_xdg_home)}"
        echo "$add_config_block_output"
        return 1
    fi
}
