#!/bin/bash
# sandbox-utils.sh - Simple sandbox management utilities for CCTK testing
# Provides two fundamental functions: create_sandbox, cleanup_sandbox
# Tests should use explicit subshells: (create_sandbox; commands)

# Sandbox configuration
SANDBOX_PREFIX="claude-toolkit-test-sandbox"

# Command masking configuration
SANDBOX_MASKED_COMMANDS=()  # Array of currently masked commands
SANDBOX_FAKE_BIN_DIR=""     # Directory containing fake commands

# Setup fake bash shell executable and configuration
setup_fake_bash_shell() {
    # Create fake shell executables directory
    mkdir -p "$sandbox_dir/bin"

    # Create fake bash executable
    echo '#!/bin/bash' > "$sandbox_dir/bin/bash"
    chmod +x "$sandbox_dir/bin/bash"

    # Create bash configuration file
    local os
    os="$(uname 2>/dev/null || printf 'Unknown')"
    if [[ "$os" == "Darwin" ]]; then
      touch "$sandbox_dir/.bash_profile"
    else
      touch "$sandbox_dir/.bashrc"
    fi

    # Add fake shell to PATH so it gets detected (avoid duplicates)
    if [[ ":$PATH:" != *":$sandbox_dir/bin:"* ]]; then
        export PATH="$sandbox_dir/bin:$PATH"
    fi
}

# Setup fake zsh shell executable and configuration
setup_fake_zsh_shell() {
    # Create fake shell executables directory
    mkdir -p "$sandbox_dir/bin"

    # Create fake zsh executable
    echo '#!/bin/bash' > "$sandbox_dir/bin/zsh"
    chmod +x "$sandbox_dir/bin/zsh"

    # Create zsh configuration file
    touch "$sandbox_dir/.zshrc"

    # Add fake shell to PATH so it gets detected (avoid duplicates)
    if [[ ":$PATH:" != *":$sandbox_dir/bin:"* ]]; then
        export PATH="$sandbox_dir/bin:$PATH"
    fi
}

# Setup fake fish shell executable and configuration
setup_fake_fish_shell() {
    # Create fake shell executables directory
    mkdir -p "$sandbox_dir/bin"

    # Create fake fish executable
    echo '#!/bin/bash' > "$sandbox_dir/bin/fish"
    chmod +x "$sandbox_dir/bin/fish"

    # Create fish configuration file
    mkdir -p "$sandbox_dir/.config/fish"
    touch "$sandbox_dir/.config/fish/config.fish"

    # Add fake shell to PATH so it gets detected (avoid duplicates)
    if [[ ":$PATH:" != *":$sandbox_dir/bin:"* ]]; then
        export PATH="$sandbox_dir/bin:$PATH"
    fi
}

# Setup all supported fake shells
setup_fake_all_shells() {
    setup_fake_bash_shell
    setup_fake_zsh_shell
    setup_fake_fish_shell
}

# Create a fake command that fails realistically
create_fake_command() {
    local fake_cmd_path="$1"
    local cmd_name="$2"

    cat > "$fake_cmd_path" << EOF
#!/bin/bash
echo "bash: $cmd_name: command not found" >&2
exit 127
EOF
    chmod +x "$fake_cmd_path"
}

# Set up command builtin override to make masked commands appear absent
setup_command_override() {
    # Store original command builtin
    if [[ -z "${ORIGINAL_COMMAND_BUILTIN:-}" ]]; then
        # Create a function that captures the original behavior
        eval "original_command_builtin() { builtin command \"\$@\"; }"
        export -f original_command_builtin
        export ORIGINAL_COMMAND_BUILTIN="true"
    fi

    # Override command builtin with a function
    command() {
        local cmd_to_check=""
        local return_exit_code=false

        # Parse arguments to find what command we're checking
        if [[ "$1" == "-v" ]] && [[ -n "${2:-}" ]]; then
            cmd_to_check="$2"
        elif [[ "$1" == "-V" ]] && [[ -n "${2:-}" ]]; then
            cmd_to_check="$2"
        fi

        # If checking for a masked command, return failure
        if [[ -n "$cmd_to_check" ]]; then
            # Handle empty or unset array safely for strict mode (set -u)
            # Check if array is declared and has elements
            if declare -p SANDBOX_MASKED_COMMANDS >/dev/null 2>&1 && [[ ${#SANDBOX_MASKED_COMMANDS[@]} -gt 0 ]]; then
                for masked_cmd in "${SANDBOX_MASKED_COMMANDS[@]}"; do
                    if [[ "$masked_cmd" == "$cmd_to_check" ]]; then
                        return 1  # Command not found
                    fi
                done
            fi
        fi

        # For non-masked commands or other uses, call original
        original_command_builtin "$@"
    }

    # Export the function so subshells see it
    export -f command
}

# Set up command masking in the sandbox
setup_command_masking() {
    local sandbox_dir="$1"
    local masked_commands="$2"
    
    # Create fake bin directory
    SANDBOX_FAKE_BIN_DIR="$sandbox_dir/.sandbox-fake-bin"
    mkdir -p "$SANDBOX_FAKE_BIN_DIR"
    
    # Convert comma-separated list to array and trim whitespace
    IFS=',' read -ra raw_commands <<< "$masked_commands"
    SANDBOX_MASKED_COMMANDS=()
    for cmd in "${raw_commands[@]}"; do
        # Trim whitespace from each command
        cmd=$(echo "$cmd" | tr -d ' ')
        if [[ -n "$cmd" ]]; then
            SANDBOX_MASKED_COMMANDS+=("$cmd")
        fi
    done
    
    # Create fake commands
    for cmd in "${SANDBOX_MASKED_COMMANDS[@]}"; do
        create_fake_command "$SANDBOX_FAKE_BIN_DIR/$cmd" "$cmd"
    done
    
    # Prepend fake bin to PATH (shadows real commands)
    export PATH="$SANDBOX_FAKE_BIN_DIR:$PATH"

    # Override the command builtin to return failure for masked commands
    setup_command_override
}

# Check if a command is currently masked
is_command_masked() {
    local cmd="$1"
    # Handle empty or unset array safely for strict mode (set -u)
    # Check if array is declared and has elements
    if declare -p SANDBOX_MASKED_COMMANDS >/dev/null 2>&1 && [[ ${#SANDBOX_MASKED_COMMANDS[@]} -gt 0 ]]; then
        for masked_cmd in "${SANDBOX_MASKED_COMMANDS[@]}"; do
            if [[ "$masked_cmd" == "$cmd" ]]; then
                return 0
            fi
        done
    fi
    return 1
}

# List currently masked commands
list_masked_commands() {
    if ! declare -p SANDBOX_MASKED_COMMANDS >/dev/null 2>&1 || [[ ${#SANDBOX_MASKED_COMMANDS[@]} -eq 0 ]]; then
        echo "No commands are currently masked"
    else
        echo "Masked commands: ${SANDBOX_MASKED_COMMANDS[*]}"
    fi
}

# Clean up sandbox with safety checks
cleanup_sandbox() {
    local sandbox_dir="$1"

    # Clean up masking state
    if [[ -n "${SANDBOX_FAKE_BIN_DIR:-}" ]]; then
        # Remove fake bin from PATH more robustly
        local new_path=""
        IFS=':' read -ra path_parts <<< "$PATH"
        for path_part in "${path_parts[@]}"; do
            if [[ "$path_part" != "$SANDBOX_FAKE_BIN_DIR" ]]; then
                if [[ -z "$new_path" ]]; then
                    new_path="$path_part"
                else
                    new_path="$new_path:$path_part"
                fi
            fi
        done
        export PATH="$new_path"
        SANDBOX_FAKE_BIN_DIR=""
        SANDBOX_MASKED_COMMANDS=()

        # Restore original command builtin
        if [[ -n "${ORIGINAL_COMMAND_BUILTIN:-}" ]]; then
            unset -f command  # Remove our override function
            unset -f original_command_builtin  # Clean up helper function
            unset ORIGINAL_COMMAND_BUILTIN
        fi
    fi

    # Safety checks
    if [[ -z "$sandbox_dir" ]]; then
        echo "ERROR: No sandbox directory specified for cleanup" >&2
        return 1
    fi

    # Don't allow cleanup of root or common system directories
    if [[ "$sandbox_dir" == "/" ]] || [[ "$sandbox_dir" == "/tmp" ]] || [[ "$sandbox_dir" == "/var" ]]; then
        echo "ERROR: Refusing to clean up system directory: $sandbox_dir" >&2
        return 1
    fi

    # Ensure it's actually a test sandbox directory
    if [[ "$sandbox_dir" != *"$SANDBOX_PREFIX"* ]]; then
        echo "ERROR: Directory does not appear to be a test sandbox: $sandbox_dir" >&2
        return 1
    fi

    # Additional safety: ensure it's in /tmp or /var/folders (common temp locations)
    if [[ "$sandbox_dir" != /tmp/* ]] && [[ "$sandbox_dir" != /var/folders/* ]]; then
        echo "ERROR: Sandbox directory not in expected temporary location: $sandbox_dir" >&2
        return 1
    fi

    if [[ -d "$sandbox_dir" ]]; then
        rm -rf "$sandbox_dir"
    fi

    return 0
}

# Create an isolated sandbox directory and set up environment
# This function creates the sandbox, sets environment variables, and changes to the sandbox directory
# Usage: Call within a subshell to isolate environment and directory changes
#   (
#       commands_to_mask="jq,wget"  # Optional: specify commands to mask
#       create_sandbox
#       # Your test commands here - they run in the sandbox environment
#   )
create_sandbox() {
    local activate_trap="${1:-true}"

    local temp_sandbox_dir
    temp_sandbox_dir=$(mktemp -d -t "${SANDBOX_PREFIX}-$$")

    local script_root_dir
    script_root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

    # Export sandbox directory and set up sandbox environment
    export sandbox_dir="$temp_sandbox_dir"
    export script_root_dir="$script_root_dir"
    export HOME="$temp_sandbox_dir"
    export XDG_DATA_HOME="$temp_sandbox_dir/.local/share"
    export XDG_CONFIG_HOME="$temp_sandbox_dir/.config"
    export XDG_CACHE_HOME="$temp_sandbox_dir/.cache"
    export XDG_CONFIG_HOME="$temp_sandbox_dir/.config"
    export ZDOTDIR="$temp_sandbox_dir"
    export XDG_BIN_DIR="$temp_sandbox_dir/.local/bin"
    export PATH="$XDG_BIN_DIR:$PATH"

    # Handle command masking if requested
    if [[ -n "${commands_to_mask:-}" ]]; then
        setup_command_masking "$temp_sandbox_dir" "$commands_to_mask"
    fi

    cd "$script_root_dir" || {
        echo "ERROR: Failed to change to script root directory: $script_root_dir" >&2
        return 1
    }

    if [[ "$activate_trap" == true ]]; then
        # shellcheck disable=SC2064
        trap "cleanup_sandbox '$temp_sandbox_dir'" EXIT
        # shellcheck disable=SC2064
        trap "cleanup_sandbox '$temp_sandbox_dir'" ERR
    fi
}

# Export functions for use in tests
export -f \
cleanup_sandbox \
create_fake_command \
create_sandbox \
is_command_masked \
list_masked_commands \
setup_command_masking \
setup_command_override \
setup_fake_all_shells \
setup_fake_bash_shell \
setup_fake_fish_shell \
setup_fake_zsh_shell
