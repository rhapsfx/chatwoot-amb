#!/bin/bash

# Template Management Library
# Shared functions for managing prompt templates (slash commands and subagents)
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

# Source the base library
source "$script_dir/library.sh"

# Template type constants
TEMPLATE_TYPE_COMMANDS="commands"
TEMPLATE_TYPE_AGENTS="agents"

# get_templates_cache_dir - Returns templates cache directory
get_templates_cache_dir() {
    printf '%s/claude-templates' "$(get_xdg_cache_home)"
}

# get_templates_config_dir - Returns templates configuration directory
get_templates_config_dir() {
    printf '%s/claude-templates' "$(get_xdg_config_home)"
}

# get_template_sources_config_file - Returns templates configuration file path
get_template_sources_config_file() {
    printf '%s/sources.csv' "$(get_templates_config_dir)"
}

# get_template_install_dir - Returns installation directory for template type
get_template_install_dir() {
    local template_type="$1"
    case "$template_type" in
        "$TEMPLATE_TYPE_COMMANDS")
            printf '%s/.claude/commands' "$(get_xdg_home)"
            ;;
        "$TEMPLATE_TYPE_AGENTS")
            printf '%s/.claude/agents' "$(get_xdg_home)"
            ;;
        *)
            log_error "Invalid template type: $template_type"
            return 1
            ;;
    esac
}

# get_template_source_subdirectory - Returns repository subdirectory for template type
get_template_source_subdirectory() {
    local template_type="$1"
    case "$template_type" in
        "$TEMPLATE_TYPE_COMMANDS")
            echo "slash-commands"
            ;;
        "$TEMPLATE_TYPE_AGENTS")
            echo "agents"
            ;;
        *)
            log_error "Invalid template type: $template_type"
            return 1
            ;;
    esac
}

# calculate_repo_hash - Calculate hash for repository URL
calculate_repo_hash() {
    local repo_url="$1"
    printf '%s' "$repo_url" | compute_checksum
}

# get_cached_template_repository_dir - Get cache directory for a source repository
get_cached_template_repository_dir() {
    local source_name="$1"
    local git_url="$2"

    local repo_hash
    repo_hash="$(calculate_repo_hash "$git_url")"
    local cache_base_dir
    cache_base_dir="$(get_templates_cache_dir)"

    printf '%s/%s/%s' "$cache_base_dir" "$repo_hash" "$source_name"
}

# validate_source_name - Validate source name format
validate_source_name() {
    local source_name="$1"
    
    # Check if empty
    if [[ -z "$source_name" ]]; then
        return 1
    fi
    
    # Check for reserved names
    if [[ "$source_name" == "user" || "$source_name" == "all" ]]; then
        return 1
    fi

    # Check format: alphanumeric with hyphens and underscores
    if [[ ! "$source_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi
    
    return 0
}

# validate_git_url - Basic validation of git URL format
validate_git_url() {
    local git_url="$1"
    
    # Check if empty
    if [[ -z "$git_url" ]]; then
        return 1
    fi
    
    # Check for basic git URL patterns
    if [[ "$git_url" =~ ^(https?://|git@|ssh://git@|/|file://) ]]; then
        return 0
    fi
    
    return 1
}

# ensure_template_sources_config - Create templates config directory and file if needed
ensure_template_sources_config() {
    local config_dir
    config_dir="$(get_templates_config_dir)"
    local config_file
    config_file="$(get_template_sources_config_file)"
    
    # Create config directory
    if ! mkdir -p "$config_dir" 2>/dev/null; then
        log_error "Cannot create configuration directory: ~${config_dir/#$(get_xdg_home)}"
        log_error "Check directory permissions"
        return 1
    fi
    
    # Create empty config file with header if it doesn't exist
    if [[ ! -f "$config_file" ]]; then
        if ! cat > "$config_file" <<'EOF' 2>/dev/null; then
# Claude Template Sources Configuration
# Format: source_name<TAB>git_url
# Lines starting with # are comments
EOF
            log_error "Cannot create configuration file: ~${config_file/#$(get_xdg_home)}"
            log_error "Check directory permissions"
            return 1
        fi
    fi
}

# Read entire templates configuration
# stdout: lines "source_name<TAB>git_url"
read_template_sources_config() {
    local config_file
    config_file="$(get_template_sources_config_file)"
    
    if [[ -f "$config_file" ]]; then
        # Read file, skip comments and empty lines
        grep -v '^[[:space:]]*#' "$config_file" | grep -v '^[[:space:]]*$'
    fi
}

# Write templates configuration
# stdin: lines "source_name<TAB>git_url"
write_template_sources_config() {
    local config_file
    config_file="$(get_template_sources_config_file)"
    
    ensure_template_sources_config || return $?
    
    # Create new file with header
    if ! {
        cat <<'EOF'
# Claude Template Sources Configuration
# Format: source_name<TAB>git_url
# Lines starting with # are comments
EOF
        # Add content from stdin, sorted alphabetically by source name
        sort -t$'\t' -k1,1
    } > "$config_file" 2>/dev/null; then
        log_error "Cannot write to configuration file: ~${config_file/#$(get_xdg_home)}"
        log_error "Check directory permissions"
        return 1
    fi
}

# Check if source exists in configuration
template_source_exists() {
    local source_name="$1"
    
    # Read config and check if source name exists in first column
    read_template_sources_config | cut -f1 | grep -Fxq "$source_name"
}

# Get URL for specific source
get_template_source_url() {
    local source_name="$1"
    
    # Read config and find matching source name, return URL (second column)
    read_template_sources_config | while IFS=$'\t' read -r name url; do
        if [[ "$name" == "$source_name" ]]; then
            echo "$url"
            return 0
        fi
    done
}

# Add source to configuration
add_template_source_to_config() {
    local source_name="$1"
    local repo_url="$2"
    
    # Check if source already exists
    if template_source_exists "$source_name"; then
        return 1
    fi
    
    # Read existing config, add new source, and write back
    {
        read_template_sources_config
        printf '%s\t%s\n' "$source_name" "$repo_url"
    } | write_template_sources_config || return 1
}

# Remove source from configuration
remove_template_source_from_config() {
    local source_name="$1"
    
    # Read config, filter out the source to remove, and write back
    read_template_sources_config | while IFS=$'\t' read -r name url; do
        if [[ "$name" != "$source_name" ]]; then
            printf '%s\t%s\n' "$name" "$url"
        fi
    done | write_template_sources_config
}

# Expand source specification to list of source records
# stdout: lines "source_name<TAB>git_url"
expand_template_source_list() {
    local source_spec="$1"

    case "$source_spec" in
        "all")
            # Return all configured sources + user source
            read_template_sources_config
            ;;
#        "user")
#            # Special case - user is a virtual source, not a real repository
#            echo "user	"
#            ;;
        *,*)
            # Comma-separated list of sources - validate each one exists and return full records
            local source_list
            source_list=$(echo "$source_spec" | tr ',' '\n')
            local available_sources_config
            available_sources_config=$(read_template_sources_config)
            
            while IFS= read -r source_name; do
                [[ -n "$source_name" ]] || continue
                # Skip validation for special virtual sources
                if [[ "$source_name" == "user" ]]; then
                    echo "user	"
                    continue
                fi
                
                # Check if source exists in configuration and return full record
                local source_record
                source_record=$(echo "$available_sources_config" | grep "^$source_name	")
                if [[ -n "$source_record" ]]; then
                    echo "$source_record"
                else
                    log_error "Source '$source_name' not found in configuration"
                    return 1
                fi
            done <<< "$source_list"
            ;;
        *)
            # Single source name - validate it exists and return full record
            if [[ "$source_spec" == "user" ]]; then
                echo "user	"
                return 0
            fi
            
            # Check if source exists in configuration and return full record
            local available_sources_config
            available_sources_config=$(read_template_sources_config)
            local source_record
            source_record=$(echo "$available_sources_config" | grep "^$source_spec	")
            if [[ -n "$source_record" ]]; then
                echo "$source_record"
            else
                log_error "Source '$source_spec' not found in configuration"
                return 1
            fi
            ;;
    esac
}

# Expand source specification for uninstall operations (never includes user templates when "all" is specified)
# User templates are completely protected and should never be processed by uninstall operations
# stdout: lines "source_name<TAB>git_url"
expand_template_source_list_for_uninstall() {
    local source_spec="$1"

    case "$source_spec" in
        "all")
            # Use special marker to indicate all non-user files should be processed
            echo "ALL_NON_USER_FILES"
            ;;
        "user")
            # This should never be reached due to validation in uninstall operations
            log_error "INTERNAL ERROR: expand_template_source_list_for_uninstall called with 'user' - this should be blocked earlier"
            return 1
            ;;
        *,*)
            # Comma-separated list of sources - validate none are user and return full records
            local source_list
            source_list=$(echo "$source_spec" | tr ',' '\n')
            local available_sources_config
            available_sources_config=$(read_template_sources_config)
            
            while IFS= read -r source_name; do
                [[ -n "$source_name" ]] || continue
                
                # This should never be reached due to validation in uninstall operations
                if [[ "$source_name" == "user" ]]; then
                    log_error "INTERNAL ERROR: expand_template_source_list_for_uninstall called with 'user' in list - this should be blocked earlier"
                    return 1
                fi
                
                # Check if source exists in configuration and return full record
                local source_record
                source_record=$(echo "$available_sources_config" | grep "^$source_name	")
                if [[ -n "$source_record" ]]; then
                    echo "$source_record"
                else
                    # For comma-separated lists, output a placeholder record for unconfigured sources
                    # The find_template_files_to_uninstall function will still find files by source field
                    echo "$source_name	UNCONFIGURED_SOURCE"
                fi
            done <<< "$source_list"
            ;;
        *)
            # Single source name - validate it exists and is not user
            if [[ "$source_spec" == "user" ]]; then
                # This should never be reached due to validation in uninstall operations
                log_error "INTERNAL ERROR: expand_template_source_list_for_uninstall called with 'user' - this should be blocked earlier"
                return 1
            fi
            
            # Check if source exists in configuration and return full record
            local available_sources_config
            available_sources_config=$(read_template_sources_config)
            local source_record
            source_record=$(echo "$available_sources_config" | grep "^$source_spec	")
            if [[ -n "$source_record" ]]; then
                echo "$source_record"
            else
                # For single source, output a placeholder record for unconfigured sources
                # The find_template_files_to_uninstall function will still find files by source field
                echo "$source_spec	UNCONFIGURED_SOURCE"
            fi
            ;;
    esac
}

# Validate directory permissions (without creating directories)
validate_template_install_directory_permissions() {
    local install_dir="$1"
    
    log_debug "validate_directory_permissions(~${install_dir/#$(get_xdg_home)})"

    local parent_dir
    parent_dir="$(dirname "$install_dir")"
    
    # Check if parent directory exists and is writable
    if [[ -d "$parent_dir" ]]; then
        # Parent directory exists - check if it's writable
        if [[ ! -w "$parent_dir" ]]; then
            log_error "Cannot write to parent directory: ~${parent_dir/#$(get_xdg_home)}"
            log_error "Please check directory permissions"
            return 1
        fi
    else
        # Parent directory doesn't exist - check if we can create it
        # by checking if its parent (usually $HOME) is writable
        local grandparent_dir
        grandparent_dir="$(dirname "$parent_dir")"
        if [[ ! -d "$grandparent_dir" ]]; then
            log_error "Grandparent directory does not exist: $grandparent_dir"
            log_error "Cannot create directory structure - grandparent directory missing"
            return 1
        fi
        
        if [[ ! -w "$grandparent_dir" ]]; then
            log_error "Cannot write to grandparent directory: $grandparent_dir"
            log_error "Cannot create parent directory - insufficient permissions"
            return 1
        fi
        
        log_debug "Parent directory ~${parent_dir/#$(get_xdg_home)} does not exist but can be created"
    fi
    
    # Check if templates directory exists and is writable (if it exists)
    if [[ -d "$install_dir" ]]; then
        if [[ ! -w "$install_dir" ]]; then
            log_error "Cannot write to templates directory: ~${install_dir/#$(get_xdg_home)}"
            log_error "Please check directory permissions"
            return 1
        fi
        log_debug "Templates directory exists and is writable"
    else
        log_debug "Templates directory does not exist but can be created"
    fi
    
    return 0
}

# Create templates directory with proper permissions
create_template_install_directory() {
    local install_dir="$1"
    
    log_debug "create_template_install_directory(~${install_dir/#$(get_xdg_home)})"

    if [[ -d "$install_dir" ]]; then
        log_debug "Directory already exists: ~${install_dir/#$(get_xdg_home)}"
        return 0
    fi

    mkdir -p "$install_dir" || return $?

    # Ensure proper permissions
    chmod 755 "$install_dir" || return $?

    return 0
}

# Get all template file paths from directory (without filtering)
# argument: directory path
# stdout: lines, full file paths for all .md files
get_template_files() {
    local dir="$1"
    
    if [[ ! -d "$dir" ]]; then
        # Non-existing dir is OK, we just don't stream anything
        return 0
    fi
    
    # Scan for all .md files, output full paths to stdout
    for file_path in "$dir"/*.md; do
        # Skip if not a file
        [[ -f "$file_path" ]] || continue
        echo "$file_path"
    done
}

# get_template_file_source - Extract source from template file
get_template_file_source() {
    local file_path="$1"

    # Check if file exists and is readable
    if [[ ! -f "$file_path" ]] || [[ ! -r "$file_path" ]]; then
        return 1
    fi

    # Extract source from YAML frontmatter
    local source_line
    source_line="$(head -n 10 "$file_path" 2>/dev/null | grep "^source:[[:space:]]*" | head -n 1)"

    if [[ -n "$source_line" ]]; then
        echo "$source_line" | sed 's/^source:[[:space:]]*//' | sed 's/[[:space:]]*$//'
        return 0
    fi

    # Default to user if no source marker found
    echo "user"
    return 0
}

# Filter template file paths to only include templates from specified source
# argument: source spec
# stdin: lines, file paths
# stdout: lines, file paths
filter_template_files_by_source() {
    local source_spec="$1"
    
    while IFS= read -r file_path; do
        [[ -n "$file_path" ]] || continue

        if [[ "$source_spec" == "all" ]]; then
            echo "$file_path"
            continue
        fi

        local file_source
        file_source="$(get_template_file_source "$file_path")"

        # Handle comma-separated sources
        if [[ "$source_spec" == *,* ]]; then
            # Convert comma-separated list to individual sources
            local source_list
            source_list=$(echo "$source_spec" | tr ',' '\n')
            local found=false
            while IFS= read -r single_source; do
                [[ -n "$single_source" ]] || continue
                if [[ "$file_source" == "$single_source" ]]; then
                    found=true
                    break
                fi
            done <<< "$source_list"
            if [[ "$found" == true ]]; then
                echo "$file_path"
            fi
        else
            # Single source
            if [[ "$file_source" == "$source_spec" ]]; then
                echo "$file_path"
            fi
        fi
    done
}

# Generate stable unique name for installed template based on source it comes from
# argument 1: original template filename (e.g., "add-command.md")
# argument 2: source name
# stdout: stable unique name (e.g., "add-command-claude-toolkit.md")
generate_stable_template_file_name() {
    local original_name="$1"
    local source_name="$2"
    local base_name="${original_name%.md}"
    printf '%s-%s.md' "$base_name" "$source_name"
}

# clone_or_update_repository - Clone repository or update if it exists
clone_or_update_repository() {
    local git_url="$1"
    local target_dir="$2"

    log_debug "clone_or_update_repository($git_url, ~${target_dir/#$(get_xdg_home)})"

    if [[ -d "$target_dir/.git" ]]; then
        # Repository exists, update it
        log_debug "Updating existing repository: ~${target_dir/#$(get_xdg_home)}"
        (
            cd "$target_dir" || return 1
            git fetch origin >/dev/null 2>&1 || return 1
            git reset --hard origin/HEAD >/dev/null 2>&1 || return 1
        )
    else
        # Clone fresh repository
        log_debug "Cloning repository: $git_url -> ~${target_dir/#$(get_xdg_home)}"
        mkdir -p "$(dirname "$target_dir")" || return 1
        local output
        if ! output=$(git clone "$git_url" "$target_dir" 2>&1); then
            log_error "Error cloning repository $git_url"
            log_error "$output"
            return 1
        fi
    fi
}

# Clones or updates source repositories
# stdin: lines "source_name<TAB>git_url"
# stdout: lines "source_name<TAB>repo_dir"
clone_or_update_template_source_repositories() {
    log_debug "clone_or_update_template_source_repositories"
    while IFS=$'\t' read -r source_name git_url; do
        [[ -n "$source_name" ]] || continue
        [[ -n "$git_url" ]] || continue

        local repo_dir
        repo_dir="$(get_cached_template_repository_dir "$source_name" "$git_url")"

        clone_or_update_repository "$git_url" "$repo_dir"

        printf '%s\t%s\n' "$source_name" "$repo_dir"
    done
}

# Finds template files in sources for specific template type
# argument: template_type (commands or agents)
# stdin:  lines "source_name<TAB>repo_dir"
# stdout: lines "source_name<TAB>file_path"
find_template_files_in_sources() {
    local template_type="$1"
    local subdirectory
    subdirectory="$(get_template_source_subdirectory "$template_type")"
    
    log_debug "find_template_files_in_sources($template_type)"
    while IFS=$'\t' read -r source_name repo_dir; do
        local source_files
        source_files=$(get_template_files "$repo_dir/$subdirectory")

        if [[ -z "$source_files" ]]; then
            log_warning "No $template_type found in source '$source_name'"
            continue
        fi

        while IFS= read -r file_path; do
            printf '%s\t%s\n' "$source_name" "$file_path"
        done <<< "$source_files"
    done
}

# copy_file - Copy file with proper error handling
copy_file() {
    local source_name="$1"
    local file_path="$2"
    local dest_path="$3"
    log_debug "copy_file($source_name, ~${file_path/#$(get_xdg_home)}, ~${dest_path/#$(get_xdg_home)})"
    local captured_output
    if captured_output=$(cp "$file_path" "$dest_path" 2>&1); then
        chmod 644 "$dest_path"
        printf '%s\t%s\t%s\n' "$source_name" "$file_path" "success"
    else
        printf '%s\t%s\t%s\t%s\n' "$source_name" "$file_path" "failure" "$captured_output"
    fi
}

# add_template_source - Add a new template source repository
add_template_source() {
    local source_name="$1"
    local git_url="$2"
    
    log_function "add_template_source($source_name, $git_url)"
    
    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi
    
    log_info "Adding source repository..."
    
    # Validate source name
    if ! validate_source_name "$source_name"; then
        log_error "Invalid source name: $source_name"
        log_info "Source names must be alphanumeric with hyphens, and cannot be 'user' or 'all'"
        return 1
    fi
    
    # Validate git URL
    if ! validate_git_url "$git_url"; then
        log_error "Invalid git URL: $git_url"
        log_info "Git URLs must start with https://, git@, ssh://git@, file://, or /"
        return 1
    fi
    
    # Check if source already exists
    if template_source_exists "$source_name"; then
        log_error "Source '$source_name' already exists"
        log_info "Use 'remove-source $source_name' first to replace it"
        return 1
    fi
    
    # Check if URL is already used by another source
    local existing_source
    existing_source=$(read_template_sources_config | while IFS=$'\t' read -r name url; do
        if [[ "$url" == "$git_url" && "$name" != "$source_name" ]]; then
            echo "$name"
            break
        fi
    done)
    
    if [[ -n "$existing_source" ]]; then
        log_error "Repository URL already used by source '$existing_source'"
        log_info "Use 'remove-source $existing_source' first or choose a different repository"
        return 1
    fi

    # Add source to configuration
    add_template_source_to_config "$source_name" "$git_url"
    
    # Cache the repository
    local repo_dir
    repo_dir="$(get_cached_template_repository_dir "$source_name" "$git_url")"
    
    # Ensure cache directory exists
    mkdir -p "$(dirname "$repo_dir")"
    
    # Clone repository to cache
    if ! git clone "$git_url" "$repo_dir" >/dev/null 2>&1; then
        log_error "Failed to cache repository"
        # Remove from config if caching failed
        remove_template_source_from_config "$source_name"
        return 1
    fi
    
    log_success "Added source '$source_name': $git_url"
    log_info "Use 'install --source $source_name' to install templates from this source"
}

# remove_template_source - Remove a template source repository
remove_template_source() {
    local source_name="$1"
    local template_type="${2:-}"  # Optional template type for validation
    
    log_function "remove_template_source($source_name)"
    
    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi
    
    log_info "Removing source repository..."
    
    # Check if source exists
    if ! template_source_exists "$source_name"; then
        log_error "Source '$source_name' not found"
        log_info "Use 'list-sources' to see available sources"
        return 1
    fi
    
    # Cannot remove claude-toolkit source (it's auto-managed)
    if [[ "$source_name" == "claude-toolkit" ]]; then
        log_error "Cannot remove auto-managed source '$source_name'"
        log_info "This source is automatically managed by the toolkit"
        return 1
    fi
    
    # If template type is specified, check for installed templates of that type
    if [[ -n "$template_type" ]]; then
        local install_dir
        install_dir="$(get_template_install_dir "$template_type")"

        # Check if any templates are installed from this source
        local installed_files_from_source
        installed_files_from_source=$(get_template_files "$install_dir" | filter_template_files_by_source "$source_name")
        
        if [[ -n "$installed_files_from_source" ]]; then
            log_error "Cannot remove source '$source_name' - $template_type are still installed from this source:"
            echo "$installed_files_from_source" | while IFS= read -r file_path; do
                log_error "  - ~${file_path/#$(get_xdg_home)}"
            done
            log_info "Uninstall $template_type from this source first"
            return 1
        fi
    fi
    
    # Remove source from configuration
    remove_template_source_from_config "$source_name"
    
    log_success "Removed source '$source_name'"
}

# list_template_sources - List all configured template sources
list_template_sources() {
    local porcelain="$1"

    log_function "list_template_sources"
    
    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    local sources_config
    sources_config="$(read_template_sources_config)"

    if [[ "$porcelain" == true ]]; then
        echo "$sources_config"
        return 0
    fi
    
    if [[ -z "$sources_config" ]]; then
        log_info "No sources configured"
        log_info "Add sources with: <script> add-source <name> <git-url>"
        return 0
    fi
    
    echo "Configured sources:"
    echo ""

    echo "$sources_config" | while IFS=$'\t' read -r source_name url; do
        printf "%-20s %s\n" "$source_name" "$url"
    done

    printf "%-20s %s\n" "user" "(user-defined templates)"
}

# initialize_claude_toolkit_template_source - Auto-configure claude-toolkit source
initialize_claude_toolkit_template_source() {
    log_function "initialize_claude_toolkit_template_source"

    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    # Check if claude-toolkit source already exists
    if template_source_exists "claude-toolkit"; then
        log_debug "claude-toolkit source already configured"
        return 0
    fi

    # Try to get origin URL from git
    local origin_url="${DEFAULT_REMOTE_REPOSITORY:-}"
    if [[ -z "$origin_url" ]]; then
        if ! origin_url="$(git remote get-url origin 2>/dev/null)"; then
            log_warning "Could not determine git origin URL - claude-toolkit source not auto-configured"
            log_info "Add claude-toolkit source manually with: <script> add-source claude-toolkit <git-url>"
            return 0
        fi
    fi

    log_debug "Auto-configuring claude-toolkit source from git origin: $origin_url"
    add_template_source_to_config "claude-toolkit" "$origin_url" || return 1
    log_debug "Auto-configured claude-toolkit source"
}

# Template Installation Snapshot Management Functions

# get_template_snapshot_file - Returns path to snapshot file for template type
get_template_snapshot_file() {
    local template_type="$1"
    local cache_dir
    cache_dir="$(get_templates_cache_dir)"
    printf '%s/%s-snapshot.txt' "$cache_dir" "$template_type"
}

# read_template_snapshot - Read entire snapshot for template type
# stdout: lines "file_path<TAB>checksum"
read_template_snapshot() {
    local template_type="$1"
    local snapshot_file
    snapshot_file="$(get_template_snapshot_file "$template_type")"

    if [[ -f "$snapshot_file" ]]; then
        # Read file, skip comments and empty lines
        grep -v '^[[:space:]]*#' "$snapshot_file" | grep -v '^[[:space:]]*$'
    fi
}

# write_template_snapshot - Write entire snapshot for template type
# stdin: lines "file_path<TAB>checksum"
write_template_snapshot() {
    local template_type="$1"
    local snapshot_file
    snapshot_file="$(get_template_snapshot_file "$template_type")"
    local cache_dir
    cache_dir="$(dirname "$snapshot_file")"

    # Ensure cache directory exists
    if ! mkdir -p "$cache_dir" 2>/dev/null; then
        log_error "Cannot create cache directory: ~${cache_dir/#$(get_xdg_home)}"
        return 1
    fi

    # Create new file with header
    if ! {
        cat <<'EOF'
# Claude Template Snapshot
# Format: file_path<TAB>checksum
# Lines starting with # are comments
EOF
        # Add content from stdin, sorted by file path
        sort -t$'\t' -k1,1
    } > "$snapshot_file" 2>/dev/null; then
        log_error "Cannot write to snapshot file: ~${snapshot_file/#$(get_xdg_home)}"
        return 1
    fi
}

# get_template_snapshot_checksum - Get checksum for specific file from snapshot
get_template_snapshot_checksum() {
    local template_type="$1"
    local file_path="$2"

    # Read snapshot and find matching file path, return checksum
    read_template_snapshot "$template_type" | while IFS=$'\t' read -r path checksum; do
        if [[ "$path" == "$file_path" ]]; then
            echo "$checksum"
            return 0
        fi
    done
}

# update_template_snapshot_entry - Add or update single snapshot entry
update_template_snapshot_entry() {
    local template_type="$1"
    local file_path="$2"
    local new_checksum="$3"

    log_debug "update_template_snapshot_entry($template_type, ~${file_path/#$(get_xdg_home)}, $new_checksum)"

    # Read existing snapshot, update/add entry, and write back
    {
        read_template_snapshot "$template_type" | while IFS=$'\t' read -r path checksum; do
            if [[ "$path" != "$file_path" ]]; then
                printf '%s\t%s\n' "$path" "$checksum"
            fi
        done
        printf '%s\t%s\n' "$file_path" "$new_checksum"
    } | write_template_snapshot "$template_type"
}

# remove_template_snapshot_entry - Remove single snapshot entry
remove_template_snapshot_entry() {
    local template_type="$1"
    local file_path="$2"

    log_debug "remove_template_snapshot_entry($template_type, ~${file_path/#$(get_xdg_home)})"

    # Read existing snapshot, filter out entry, and write back
    read_template_snapshot "$template_type" | while IFS=$'\t' read -r path checksum; do
        if [[ "$path" != "$file_path" ]]; then
            printf '%s\t%s\n' "$path" "$checksum"
        fi
    done | write_template_snapshot "$template_type"
}

# copy_file_with_snapshot - Copy file and update snapshot on success
copy_file_with_snapshot() {
    local template_type="$1"
    local source_name="$2"
    local file_path="$3"
    local dest_path="$4"

    local result
    result=$(copy_file "$source_name" "$file_path" "$dest_path")
    echo "$result"  # Pass through the output

    # Check if it was successful and update snapshot
    if echo "$result" | grep -q $'\tsuccess$'; then
        local new_checksum
        new_checksum=$(compute_file_checksum "$dest_path")
        update_template_snapshot_entry "$template_type" "$dest_path" "$new_checksum"
    fi
}

produce_install_info() {
    local install_dir="$1"
    local source_files="$2"
    log_debug "produce_install_info(${install_dir/#$(get_xdg_home)}, ...)"

    # Extract unique sources and build lookup table
    local unique_sources
    unique_sources=$(echo "$source_files" | cut -f1 | sort | uniq)

    local source_file_lookup=""

    # Process source files (existing logic) and collect lookup data
    while IFS=$'\t' read -r source_name file_path; do
        [[ -n "$source_name" ]] || continue
        [[ -n "$file_path" ]] || continue

        # Build lookup: "source_name:basename" for files present in sources
        source_file_lookup="${source_file_lookup}${source_name}:$(basename "$file_path")"$'\n'

        # Process source file (existing logic)
        local file_source
        file_source=$(get_template_file_source "$file_path")

        local file_checksum
        file_checksum=$(compute_file_checksum "$file_path")

        local file_name
        file_name="$(basename "$file_path")"

        local dest_path="$install_dir/$file_name"

        local dest_file_name dest_source dest_checksum
        if dest_source=$(get_template_file_source "$dest_path"); then
            dest_file_name="$file_name"
            dest_checksum=$(compute_file_checksum "$dest_path")
        else
            dest_file_name=""
            dest_source=""
            dest_checksum=""
        fi

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$source_name" "$file_path" "$file_source" "$file_checksum" "$dest_file_name" "$dest_source" "$dest_checksum"
    done <<< "$source_files"

    # Get all installed files once
    local all_installed_files
    all_installed_files=$(get_template_files "$install_dir")

    # Find orphaned files - installed files not present in current sources
    while IFS= read -r installed_file_path; do
        [[ -n "$installed_file_path" ]] || continue

        # Get source of installed file
        local installed_source
        installed_source=$(get_template_file_source "$installed_file_path")

        # Only check files from sources we're currently processing
        if echo "$unique_sources" | grep -Fxq "$installed_source"; then
            # Check if this file exists in current source files
            local installed_basename
            installed_basename="$(basename "$installed_file_path")"
            local lookup_key="${installed_source}:${installed_basename}"

            # If not found in source files, it's orphaned
            if [[ "$source_file_lookup" != *"$lookup_key"$'\n'* ]]; then
                local dest_checksum
                dest_checksum=$(compute_file_checksum "$installed_file_path")

                printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$installed_source" "EMPTY" "EMPTY" "EMPTY" "$installed_basename" "$installed_source" "$dest_checksum"
            fi
        fi
    done <<< "$all_installed_files"
}

execute_install() {
    local template_type="$1"
    local install_dir="$2"
    local install_info="$3"
    log_debug "execute_install($template_type, ~${install_dir/#$(get_xdg_home)}, ...)"

    local failures_met=false

    while IFS=$'\t' read -r source_name file_path file_source file_checksum dest_file_name dest_source dest_checksum; do
        [[ -n "$source_name" ]] || continue

        if [[ "$file_path" == "EMPTY" ]]; then
            # This is an orphaned file - check snapshot to determine if safe to delete
            local orphaned_file_path="$install_dir/$dest_file_name"
            local snapshot_checksum
            snapshot_checksum=$(get_template_snapshot_checksum "$template_type" "$orphaned_file_path")
            
            if [[ -n "$snapshot_checksum" && "$dest_checksum" == "$snapshot_checksum" ]]; then
                # File is tracked in snapshot and unchanged by user - safe to delete
                log_debug "Orphaned file $dest_file_name will be removed (no user changes detected)"
                continue  # Will be processed in second phase for deletion
            else
                # File was modified by user or not tracked - report error
                if [[ -z "$snapshot_checksum" ]]; then
                    printf '%s\t%s\t%s\t%s\n' "$source_name" "EMPTY" "failure" "orphaned installed file: $dest_file_name (not tracked - possibly user-created)"
                else
                    printf '%s\t%s\t%s\t%s\n' "$source_name" "EMPTY" "failure" "orphaned installed file: $dest_file_name (contains user changes - use reinstall to force)"
                fi
                failures_met=true
                continue
            fi
        fi

        local file_name
        file_name="$(basename "$file_path")"

        if [[ "$source_name" != "$file_source" ]]; then
            printf '%s\t%s\t%s\t%s\n' "$source_name" "$file_path" "failure" "Expected 'source: $source_name' in YAML frontmatter in $file_name"
            failures_met=true
            continue
        fi

        if [[ -z "$dest_source" || "$dest_source" != "$file_source" ]]; then
            continue
        fi

        if [[ "$dest_checksum" != "$file_checksum" ]]; then
            # Check if file was modified by user using snapshot
            local dest_full_path="$install_dir/$file_name"
            local snapshot_checksum
            snapshot_checksum=$(get_template_snapshot_checksum "$template_type" "$dest_full_path")
            
            if [[ -n "$snapshot_checksum" && "$dest_checksum" == "$snapshot_checksum" ]]; then
                # File hasn't been modified by user since last install, safe to update
                log_debug "File $file_name will be updated (no user changes detected)"
            else
                # File was modified by user or not tracked, report error
                printf '%s\t%s\t%s\t%s\n' "$source_name" "$file_path" "failure" "Cannot install $file_name: destination file contains user changes (use reinstall to force)"
                failures_met=true
                continue
            fi
        fi
    done <<< "$install_info"

    if [[ $failures_met == true ]]; then
        return 0
    fi

    # Process orphaned files marked for deletion
    while IFS=$'\t' read -r source_name file_path file_source file_checksum dest_file_name dest_source dest_checksum; do
        [[ -n "$source_name" ]] || continue
        
        if [[ "$file_path" == "EMPTY" ]]; then
            # This is an orphaned file that was validated as safe to delete
            local orphaned_file_path="$install_dir/$dest_file_name"
            local snapshot_checksum
            snapshot_checksum=$(get_template_snapshot_checksum "$template_type" "$orphaned_file_path")
            
            if [[ -n "$snapshot_checksum" && "$dest_checksum" == "$snapshot_checksum" ]]; then
                # Safe to delete - remove file and update snapshot
                log_debug "Removing orphaned file $dest_file_name (no user changes detected)"
                
                local rm_error
                if rm_error=$(rm -- "$orphaned_file_path" 2>&1); then
                    printf '%s\t%s\t%s\t%s\n' "$source_name" "EMPTY" "success" "removed orphaned file: $dest_file_name"
                    # Remove from snapshot after successful removal
                    remove_template_snapshot_entry "$template_type" "$orphaned_file_path"
                else
                    printf '%s\t%s\t%s\t%s\n' "$source_name" "EMPTY" "failure" "failed to remove orphaned file: $dest_file_name ($rm_error)"
                fi
            fi
        fi
    done <<< "$install_info"

    while IFS=$'\t' read -r source_name file_path file_source file_checksum dest_file_name dest_source dest_checksum; do
        [[ -n "$source_name" ]] || continue
        [[ "$file_path" != "EMPTY" ]] || continue

        local file_name
        file_name="$(basename "$file_path")"

        if [[ -z "$dest_source" ]]; then
            copy_file_with_snapshot "$template_type" "$source_name" "$file_path" "$install_dir/$file_name"
            continue
        fi

        if [[ "$dest_source" != "$file_source" ]]; then
            # Conflicting file names, let's rename installed file at destination
            local stable_name
            stable_name=$(generate_stable_template_file_name "$file_name" "$file_source")
            copy_file_with_snapshot "$template_type" "$source_name" "$file_path" "$install_dir/$stable_name"
            continue
        fi

        if [[ "$dest_checksum" == "$file_checksum" ]]; then
            printf '%s\t%s\t%s\t%s\n' "$source_name" "$file_path" "skip" "destination is identical"
        else
            # File exists with same source but different content - this means upstream changes
            # that were validated in phase 1 as safe to update
            copy_file_with_snapshot "$template_type" "$source_name" "$file_path" "$install_dir/$file_name"
        fi
    done <<< "$install_info"
}

execute_reinstall() {
    local template_type="$1"
    local install_dir="$2"
    local install_info="$3"
    log_debug "execute_reinstall($template_type, ~${install_dir/#$(get_xdg_home)}, ...)"

    local failures_met=false

    while IFS=$'\t' read -r source_name file_path file_source file_checksum dest_file_name dest_source dest_checksum; do
        [[ -n "$source_name" ]] || continue

        if [[ "$file_path" == "EMPTY" ]]; then
            # This is an orphaned file - delete it during reinstall
            local orphaned_file_path="$install_dir/$dest_file_name"
            log_debug "execute_reinstall: removing orphaned file ~${orphaned_file_path/#$(get_xdg_home)}"

            local rm_error
            if rm_error=$(rm -- "$orphaned_file_path" 2>&1); then
                printf '%s\t%s\t%s\t%s\n' "$source_name" "EMPTY" "success" "removed orphaned file: $dest_file_name"
                # Remove from snapshot after successful removal
                remove_template_snapshot_entry "$template_type" "$orphaned_file_path"
            else
                printf '%s\t%s\t%s\t%s\n' "$source_name" "EMPTY" "failure" "failed to remove orphaned file: $dest_file_name ($rm_error)"
                failures_met=true
            fi
            continue
        fi

        [[ -n "$file_path" ]] || continue

        local file_name
        file_name="$(basename "$file_path")"

        if [[ "$source_name" != "$file_source" ]]; then
            printf '%s\t%s\t%s\t%s\n' "$source_name" "$file_path" "failure" "Expected 'source: $source_name' in YAML frontmatter in $file_name"
            failures_met=true
            continue
        fi

        if [[ -z "$dest_source" || "$dest_source" != "$file_source" ]]; then
            continue
        fi
    done <<< "$install_info"

    if [[ $failures_met == true ]]; then
        return 0
    fi

    while IFS=$'\t' read -r source_name file_path file_source file_checksum dest_file_name dest_source dest_checksum; do
        [[ -n "$source_name" ]] || continue
        [[ "$file_path" != "EMPTY" ]] || continue

        local file_name
        file_name="$(basename "$file_path")"

        if [[ -z "$dest_source" ]]; then
            copy_file_with_snapshot "$template_type" "$source_name" "$file_path" "$install_dir/$file_name"
            continue
        fi

        if [[ "$dest_source" != "$file_source" ]]; then
            # Conflicting file names, let's rename installed file at destination
            local stable_name
            stable_name=$(generate_stable_template_file_name "$file_name" "$file_source")
            copy_file_with_snapshot "$template_type" "$source_name" "$file_path" "$install_dir/$stable_name"
            continue
        fi

        if [[ "$dest_checksum" == "$file_checksum" ]]; then
            printf '%s\t%s\t%s\t%s\n' "$source_name" "$file_path" "skip" "destination is identical"
        else
            copy_file_with_snapshot "$template_type" "$source_name" "$file_path" "$install_dir/$file_name"
        fi
    done <<< "$install_info"
}

hint_restart_claude_code() {
    echo ""
    echo -e "${BLUE}Note: Restart Claude Code to refresh available prompt templates${NC}"
    echo ""
}

report_installed_template_files() {
    local installed_count=0
    local skipped_count=0
    local failed_count=0

    while IFS=$'\t' read -r source_name file_path status status_description; do
        [[ -n "$status" ]] || continue
        local file_name
        file_name="$(basename "$file_path")"
        case "$status" in
            "success")
                if [[ "$file_name" == "EMPTY" ]]; then
                    # This is an orphaned file removal - show the status description
                    local message="${status_description:-removed orphaned file}"
                    log_success "$message"
                else
                    log_debug "Successfully installed: $file_name"
                fi
                ((installed_count++))
                ;;
            "skip")
                ((skipped_count++))
                local message="${status_description:-unknown status}"
                log_warning "Skipped installing '$file_name': $message"
                ;;
            "failure")
                ((failed_count++))
                local message="${status_description:-unknown error}"
                if [[ "$file_name" == EMPTY ]]; then
                    log_error "Failed to install: $message"
                else
                    log_error "Failed to install '$file_name': $message"
                fi
                ;;
            *)
                log_warning "Unknown status for file '$file_name': $status"
                ;;
        esac
    done

    if [[ $failed_count -gt 0 ]]; then
        log_error "Encountered $failed_count failures during installation"
        return 1
    fi

    if [[ $skipped_count -gt 0 && $installed_count -eq 0 ]]; then
        log_success "All files already installed"
        return 0
    fi

    if [[ $installed_count -gt 0 ]]; then
        log_success "Successfully installed $installed_count file(s)"
        hint_restart_claude_code
    fi

    return 0
}

install_templates() {
    local template_type="$1"
    local source_spec="$2"
    local porcelain="$3"

    log_function "install_templates($source_spec, $porcelain)"

    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    log_info "Installing files from source(s): $source_spec"

    local install_dir
    install_dir="$(get_template_install_dir "$template_type")"

    validate_template_install_directory_permissions "$install_dir" || return $?

    create_template_install_directory "$install_dir" || return $?

    local source_files
    source_files=$(expand_template_source_list "$source_spec" | \
        clone_or_update_template_source_repositories | \
        find_template_files_in_sources "$template_type")

    local install_info
    install_info=$(produce_install_info "$install_dir" "$source_files")

    local install_results
    install_results=$(execute_install "$template_type" "$install_dir" "$install_info")

    if [[ "$porcelain" == true ]]; then
        # Porcelain mode: output raw results and handle errors directly
        echo "$install_results"

        # Check for failures in pipeline or individual files
        if echo "$install_results" | grep -q $'\tfailure\t'; then
            return 1
        fi
    else
        echo "$install_results" | report_installed_template_files
    fi
}

reinstall_templates() {
    local template_type="$1"
    local source_spec="$2"
    local porcelain="$3"

    log_function "reinstall_templates($source_spec, $porcelain)"

    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    log_info "Reinstalling files from source(s): $source_spec"

    local install_dir
    install_dir="$(get_template_install_dir "$template_type")"

    validate_template_install_directory_permissions "$install_dir" || return $?

    create_template_install_directory "$install_dir" || return $?

    local source_files
    source_files=$(expand_template_source_list "$source_spec" | \
        clone_or_update_template_source_repositories | \
        find_template_files_in_sources "$template_type")

    local install_info
    install_info=$(produce_install_info "$install_dir" "$source_files")

    local install_results
    install_results=$(execute_reinstall "$template_type" "$install_dir" "$install_info")

    if [[ "$porcelain" == true ]]; then
        # Porcelain mode: output raw results and handle errors directly
        echo "$install_results"

        # Check for failures in pipeline or individual files
        if echo "$install_results" | grep -q $'\tfailure\t'; then
            return 1
        fi
    else
        echo "$install_results" | report_installed_template_files
    fi
}

# Finds template files to uninstall in installation directory.
# For "all" sources, finds all non-user files regardless of source configuration
# stdin: lines "source_name<TAB>git_url" or special marker "ALL_NON_USER_FILES"
# stdout: lines "source_name<TAB>file_path"
find_template_files_to_uninstall() {
    local install_dir="$1"
    log_debug "find_template_files_to_uninstall(${install_dir/#$(get_xdg_home)})"

    local installed_files
    installed_files=$(get_template_files "$install_dir")

    # Process input line by line, handling special marker case
    while IFS=$'\t' read -r source_name git_url; do
        # Check for special marker on first iteration
        if [[ "$source_name" == "ALL_NON_USER_FILES" ]]; then
            # Find all non-user files regardless of source configuration
            while IFS= read -r file_path; do
                [[ -n "$file_path" ]] || continue
                
                local file_source
                file_source=$(get_template_file_source "$file_path")
                
                if [[ "$file_source" != "user" ]]; then
                    printf '%s\t%s\n' "$file_source" "$file_path"
                fi
            done <<< "$installed_files"
            return 0
        fi
        
        # Regular source processing
        [[ -n "$source_name" ]] || continue

        if [[ "$source_name" == "user" ]]; then
            # user files may not be uninstalled
            continue
        fi

        while IFS= read -r file_path; do
            [[ -n "$file_path" ]] || continue

            if [[ $(get_template_file_source "$file_path") == "$source_name" ]]; then
                printf '%s\t%s\n' "$source_name" "$file_path"
            fi
        done <<< "$installed_files"
    done
}

validate_template_files_before_uninstall() {
    log_debug "validate_template_files_before_uninstall"
    while IFS=$'\t' read -r source_name file_path; do
        [[ -n "$source_name" ]] || continue
        [[ -n "$file_path" ]] || continue

        if [[ "$source_name" == "user" ]]; then
            log_error "User file may not be uninstalled: ~${file_path/#$(get_xdg_home)}"
            return 1
        fi

        # Fail if file is read-only by *mode bits* (independent of EUID/ACL runtime checks)
        if is_mode_readonly "$file_path"; then
            log_error "Read-only file may not be uninstalled: ~${file_path/#$(get_xdg_home)}"
            return 1
        fi

        printf '%s\t%s\n' "$source_name" "$file_path"
    done
}

execute_uninstall() {
    local template_type="$1"  
    log_debug "execute_uninstall($template_type)"
    while IFS=$'\t' read -r source_name file_path; do
        [[ -n "$source_name" ]] || continue
        [[ -n "$file_path" ]] || continue

        log_debug "execute_uninstall: removing ~${file_path/#$(get_xdg_home)}"

        local file_name
        file_name="$(basename "$file_path")"

        local rm_error
        if rm_error=$(rm -- "$file_path" 2>&1); then
            printf '%s\t%s\n' "$file_name" "success"
            # Remove from snapshot after successful removal
            remove_template_snapshot_entry "$template_type" "$file_path"
        else
            printf '%s\t%s\t%s\n' "$file_name" "failure" "$rm_error"
        fi
    done
}

report_uninstalled_template_files() {
    local uninstalled_count=0
    local failed_count=0

    while IFS=$'\t' read -r file_name status failure_msg; do
        [[ -n "$file_name" ]] || continue

        case "$status" in
            "success")
                log_debug "Successfully uninstalled: '$file_name'"
                ((uninstalled_count++))
                ;;
            "failure")
                ((failed_count++))
                if [[ -n "$failure_msg" ]]; then
                    log_error "Failed to uninstall '$file_name': $failure_msg"
                else
                    log_error "Failed to uninstall '$file_name': unknown error"
                fi
                ;;
            *)
                log_warning "Unknown status for '$file_name': $status"
                ;;
        esac
    done

    if [[ $failed_count -gt 0 ]]; then
        log_error "Encountered $failed_count failures during uninstallation"
        return 1
    fi

    if [[ $uninstalled_count -gt 0 ]]; then
        log_success "Successfully uninstalled $uninstalled_count files(s)"
        hint_restart_claude_code
    fi

    return 0
}

# Main uninstall function - now composed of smaller stages
uninstall_templates() {
    local template_type="$1"
    local source_spec="$2"
    local auto_accept="$3"
    local porcelain="$4"

    log_function "uninstall_templates($source_spec, $auto_accept, $porcelain)"

    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    # CRITICAL: User files must NEVER be removable, even when explicitly targeted
    if [[ "$source_spec" == "user" ]] || [[ "$source_spec" == *",user,"* ]] || [[ "$source_spec" == "user,"* ]] || [[ "$source_spec" == *",user" ]]; then
        log_error "Cannot uninstall user files"
        log_error "User files can only be managed manually by the user"
        return 1
    fi

    log_info "Uninstalling files from source(s): $source_spec"

    local install_dir
    install_dir="$(get_template_install_dir "$template_type")"

    validate_template_install_directory_permissions "$install_dir" || return $?

    if [[ ! -d "$install_dir" ]]; then
        log_info "Directory ~${install_dir/#$(get_xdg_home)} is not found - nothing to uninstall"
        return 0
    fi

    local files_to_uninstall
    files_to_uninstall=$(expand_template_source_list_for_uninstall "$source_spec" | \
        find_template_files_to_uninstall "$install_dir" |
        validate_template_files_before_uninstall)

    local uninstall_file_count
    if [[ -z "$files_to_uninstall" ]]; then
        uninstall_file_count=0
    else
        uninstall_file_count=$(echo "$files_to_uninstall" | wc -l | tr -d ' ')
    fi

    local user_file_count
    user_file_count=$(get_template_files "$install_dir" | filter_template_files_by_source "user" | wc -l | tr -d ' ')

    # Check if there are files to remove
    if [[ $uninstall_file_count -eq 0 ]]; then
        if [[ "$source_spec" == "all" ]]; then
            log_info "No toolkit files found in directory ~${install_dir/#$(get_xdg_home)} - nothing to uninstall"
        else
            log_info "No [$source_spec] files found in directory ~${install_dir/#$(get_xdg_home)} - nothing to uninstall"
        fi
        return 0
    fi

    # Confirmation prompt
    if [[ "$porcelain" == true ]]; then
        # In porcelain mode, skip confirmation prompts
        :
    elif [[ "$auto_accept" == true ]]; then
        log_info "Auto-accept mode enabled - skipping confirmation prompts"
        if [[ $user_file_count -gt 0 ]]; then
            log_info "User files will be preserved"
        fi
    else
        if [[ "$source_spec" == "all" ]]; then
            log_warning "This will remove $uninstall_file_count toolkit file(s)"
        else
            log_warning "This will remove $uninstall_file_count [$source_spec] file(s)"
        fi
        if [[ $user_file_count -gt 0 ]]; then
            log_info "User files will be preserved"
        fi
        printf "Proceed with uninstall? [y/N]: " >&2
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Uninstall cancelled by user"
            return 1
        fi
        log_info "Proceeding with uninstall"
    fi

    # Execute pipeline and capture results
    local uninstall_results
    uninstall_results=$(echo "$files_to_uninstall" | \
        execute_uninstall "$template_type")

    if [[ "$porcelain" == true ]]; then
        # Porcelain mode: output raw results and handle errors directly
        echo "$uninstall_results"

        # Check for failures in pipeline or individual files
        if echo "$uninstall_results" | grep -q $'\tfailure\t'; then
            return 1
        fi
    else
        echo "$uninstall_results" | report_uninstalled_template_files
    fi
}

# Emit file info with detailed attributes
# Stdin: list of file_path
# Stdout: list of file_path<TAB>cmd_name<TAB>origin<TAB>size<TAB>mod_date<TAB>description
emit_template_file_info() {
    while IFS= read -r file_path; do
        [[ -n "$file_path" ]] || continue
        [[ -f "$file_path" ]] || continue

        local file_name
        file_name="$(basename "$file_path")"

        local source_name
        source_name=$(get_template_file_source "$file_path")

        # Get file stats
        local file_size=""
        local mod_date=""
        local description=""

        if [[ -f "$file_path" ]]; then
            # Get file size
            if command -v stat >/dev/null 2>&1; then
                if stat -f "%z" "$file_path" >/dev/null 2>&1; then
                    # macOS/BSD stat
                    file_size=$(stat -f "%z" "$file_path")
                    mod_date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$file_path")
                else
                    # GNU stat
                    file_size=$(stat -c "%s" "$file_path")
                    mod_date=$(stat -c "%y" "$file_path" | cut -d'.' -f1)
                fi
            fi

            # Extract description from YAML frontmatter
            description=$(grep "^description:" "$file_path" 2>/dev/null | sed 's/^description:[[:space:]]*//' | head -n 1)
            if [[ -z "$description" ]]; then
                description="No description available"
            fi
        else
            file_size="N/A"
            mod_date="N/A"
            description="File not accessible"
        fi

        # Output CSV format with tab separators (colons appear in timestamps)
        echo -e "${file_path}\t${file_name}\t${source_name}\t${file_size}\t${mod_date}\t${description}"
    done
}

report_listed_template_files() {
    local pipeline_output="$1"
    local install_dir="$2"
    local source_spec="$3"
    local format="$4"

    log_debug "report_listed_template_files($install_dir)"

    while IFS=$'\t' read -r file_path file_name source_name file_size mod_date description; do
        [[ -n "$file_name" ]] || continue

        if [[ "$format" == "detailed" ]]; then
            # Verbose format with detailed information

            # Format file size
            local formatted_size="$file_size"
            if [[ -n "$file_size" && "$file_size" != "N/A" ]]; then
                if [[ $file_size -gt 1024 ]]; then
                    formatted_size="$((file_size / 1024))KB"
                else
                    formatted_size="${file_size}B"
                fi
            fi

            # Display verbose information
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "File:        $file_name"
            echo "Origin:      $source_name"
            echo "Path:        $file_path"
            echo "Size:        $formatted_size"
            echo "Modified:    $mod_date"
            echo "Description: $description"
        else
            # Simple format
            echo "${file_name} ($source_name)"
        fi
    done <<< "$pipeline_output"

    # Count results for summary
    local displayed_count
    if [[ -n "$pipeline_output" ]]; then
        displayed_count=$(echo "$pipeline_output" | wc -l | tr -d ' ')
    else
        displayed_count=0
    fi

    # Only show the count message if there are files to display
    if [[ $displayed_count -gt 0 ]]; then
        log_info "Found $displayed_count file(s) ($source_spec)"
    fi
}

# List templates with filtering options using streaming pipeline architecture
list_templates() {
    local template_type="$1"
    local source_spec="$2"
    local format="$3"
    local porcelain="$4"

    log_function "list_templates($source_spec, $porcelain)"

    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    local install_dir
    install_dir="$(get_template_install_dir "$template_type")"

    local pipeline_output
    if ! pipeline_output=$(get_template_files "$install_dir" | sort | filter_template_files_by_source "$source_spec" | emit_template_file_info); then
        return 1
    fi

    if [[ "$porcelain" == true ]]; then
        echo "$pipeline_output"
    else
        report_listed_template_files "$pipeline_output" "$install_dir" "$source_spec" "$format"
    fi
}

# Generic template management CLI functions

# Show help for template management commands - parametrized for different template types
show_template_help() {
    local template_type="$1"
    local script_name="$2"
    
    case "$template_type" in
        "$TEMPLATE_TYPE_COMMANDS")
            local type_name="slash commands"
            local type_description="Claude Code Slash Commands"
            local install_location="~/.claude/commands/"
            ;;
        "$TEMPLATE_TYPE_AGENTS")
            local type_name="subagents"
            local type_description="Claude Code Subagents"
            local install_location="~/.claude/agents/"
            ;;
        *)
            log_error "Invalid template type: $template_type"
            return 1
            ;;
    esac
    
    echo "$type_description Installation Script"
    echo ""
    echo "Usage: $script_name <command> [options]"
    echo ""
    echo "Commands:"
    echo "  install [--source <name>]      Install $type_name from specified source(s)"
    echo "  reinstall [--source <name>]    Reinstall $type_name from specified source(s)"
    echo "  uninstall [--source <name>]    Remove $type_name from specified source(s)"
    echo "  list [--source <name>]         List existing $type_name from specified source(s)"
    echo ""
    echo "Global Options:"
    echo "  --dry-run                      Preview operation without making system modifications"
    echo "  --debug                        Enable debug output (verbose logging)"
    echo "  --porcelain                    Enable porcelain format (machine-readable output)"
    echo "  --yes, -y, --force             Skip confirmation prompts"
    echo "  --help, -h                     Show this help message"
    echo ""
    echo "Source Options:"
    echo "  --source all                   Operate on all configured sources (default for uninstall: removes all non-user $type_name)"
    echo "  --source <name>                Operate only on the specified source"
    echo "  --source user                  Operate only on user-created $type_name (install/list only - user $type_name cannot be uninstalled)"
    echo "  --source <name1,name2>         Operate on comma-separated list of sources"
    echo ""
    echo "List Command Options:"
    echo "  --format <format>              Output format: compact (default) or detailed"
    echo ""
    echo "Examples:"
    echo "  $script_name install                                     # Install from all sources"
    echo "  $script_name install --source claude-toolkit             # Install only from toolkit"
    echo "  $script_name install --source team-alpha,team-beta       # Install from multiple sources"
    echo "  $script_name list --source user                          # List only user $type_name"
    echo "  $script_name uninstall --source team-alpha               # Remove $type_name from one source"
    echo ""
    echo "Note: Use 'claude-template-sources' to manage template repositories:"
    echo "  claude-template-sources add team-alpha <git-url>         # Add new source"
    echo "  claude-template-sources list                             # List all sources"
    echo "  claude-template-sources remove team-alpha                # Remove source"
}

# Parse command line arguments - pure syntactic parsing, returns key-value pairs
# This function is generic and works for any template type
parse_template_arguments() {
    # Handle global help flag first
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        printf "help\ttrue\n"
        return 0
    fi
    
    # Extract command if provided, or mark as missing
    if [[ $# -eq 0 ]]; then
        printf "no_command\ttrue\n"
    else
        local command="$1"
        shift
        printf "command\t%s\n" "$command"
    fi
    
    # Parse all options syntactically - no validation
    while [[ $# -gt 0 ]]; do
        case $1 in
            --source)
                if [[ -n "${2:-}" ]] && [[ "$2" != --* ]]; then
                    printf "source\t%s\n" "$2"
                    shift 2
                else
                    printf "source_no_value\ttrue\n"
                    shift
                fi
                ;;
            --source=*)
                printf "source\t%s\n" "${1#*=}"
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
            --format)
                if [[ -n "${2:-}" ]] && [[ "$2" != --* ]]; then
                    printf "format\t%s\n" "$2"
                    shift 2
                else
                    printf "format_no_value\ttrue\n"
                    shift
                fi
                ;;
            --format=*)
                printf "format\t%s\n" "${1#*=}"
                shift
                ;;
            --yes|-y|--force)
                printf "auto_accept\ttrue\n"
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
# Parametrized for different template types
validate_template_arguments() {
    local template_type="$1"
    local command="" source="" format=""
    local help_requested=false
    local has_no_command=false

    case "$template_type" in
        "$TEMPLATE_TYPE_COMMANDS")
            local type_name="slash commands"
            ;;
        "$TEMPLATE_TYPE_AGENTS")
            local type_name="subagents"
            ;;
        *)
            printf "Invalid template type: %s\n" "$template_type"
            return 1
            ;;
    esac

    # Read key-value pairs from stdin and collect validation issues
    while IFS=$'\t' read -r key value; do
        case "$key" in
            command) command="$value" ;;
            source) source="$value" ;;
            format) format="$value" ;;
            help) help_requested=true ;;
            no_command) has_no_command=true ;;
            source_no_value)
                printf "%s\n" "--source requires a value"
                return 1
                ;;
            format_no_value)
                printf "%s\n" "--format requires a value"
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
        printf "%s\n" "Usage: <script> <command> [options]"
        printf "%s\n" "Commands: install, reinstall, uninstall, list"
        return 1
    fi
    
    # Validate command is recognized
    case "$command" in
        install|reinstall|uninstall|list)
            ;;
        *)
            printf "Unknown command: %s\n" "$command"
            printf "%s\n" "Valid commands: install, reinstall, uninstall, list"
            return 1
            ;;
    esac
    
    # Command-specific option validation (check this first before positional args)
    case "$command" in
        list)
            if [[ -n "$source" ]]; then
                # Validate source values for list command
                case "$source" in
                    all|user|*) # Accept any source name or comma-separated list
                        ;;
                esac
            fi
            if [[ -n "$format" ]]; then
                case "$format" in
                    compact|detailed)
                        ;;
                    *)
                        printf "Invalid --format for 'list' command: %s (valid: compact, detailed)\n" "$format"
                        return 1
                        ;;
                esac
            fi
            ;;
        install|reinstall|uninstall)
            if [[ -n "$format" ]]; then
                printf "%s\n" "--format option only valid for 'list' command"
                return 1
            fi
            ;;
    esac
    
    # All validations passed
    return 0
}

# Interpret parsed arguments and set variables/perform the work
# Parametrized for different template types
interpret_template_arguments() {
    local template_type="$1"
    shift
    local parsed_args="$1"
    shift
    local command source format
    local dry_run porcelain debug auto_accept help_requested

    # Initialize argument variables with defaults
    command=""
    source="all"
    format="compact"
    dry_run="$DRY_RUN"
    porcelain="$PORCELAIN"
    debug="$DEBUG"
    auto_accept=false
    help_requested=false

    # Read and interpret parsed arguments
    while IFS=$'\t' read -r key value; do
        case "$key" in
            help) help_requested=true ;;
            command) command="$value" ;;
            source) source="$value" ;;
            format) format="$value" ;;
            dry_run) dry_run=true ;;
            porcelain) porcelain=true ;;
            debug) debug=true ;;
            auto_accept) auto_accept="$value" ;;
        esac
    done <<< "$parsed_args"

    # Handle help request
    if [[ "$help_requested" == true ]]; then
        case "$template_type" in
            "$TEMPLATE_TYPE_COMMANDS")
                show_template_help "$template_type" "claude-slash"
                ;;
            "$TEMPLATE_TYPE_AGENTS")
                show_template_help "$template_type" "claude-agents"
                ;;
            *)
                log_error "Invalid template type: $template_type"
                return 1
                ;;
        esac
        exit 0
    fi

    # Set global environment variables for functions that need them
    DRY_RUN="$dry_run"
    DEBUG="$debug"

    initialize_claude_toolkit_template_source

    case "$command" in
        "install")
            install_templates "$template_type" "$source" "$porcelain"
            ;;
        "reinstall")
            reinstall_templates "$template_type" "$source" "$porcelain"
            ;;
        "uninstall")
            uninstall_templates "$template_type" "$source" "$auto_accept" "$porcelain"
            ;;
        "list")
            list_templates "$template_type" "$source" "$format" "$porcelain"
            ;;
        *)
            log_error "Unknown command: $command"
            log_info "Use --help for usage information"
            return 1
            ;;
    esac
}

# Generic main function for template management scripts
template_main() {
    local template_type="$1"
    shift
    
    local parsed_args
    parsed_args=$(parse_template_arguments "$@")
    
    local validation_result
    if ! validation_result=$(echo "$parsed_args" | validate_template_arguments "$template_type" 2>&1); then
        # Print validation errors with proper formatting
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                log_error "$line"
            fi
        done <<< "$validation_result"
        log_info "Use --help for usage information"
        return 1
    fi
    
    interpret_template_arguments "$template_type" "$parsed_args" "$@"
}
