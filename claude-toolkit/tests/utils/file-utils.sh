#!/bin/bash
# file-utils.sh - File and directory utility functions for tests
#
# Provides utility functions for file operations and checksums in test environments

# Calculate a composite checksum of all files matching a pattern in a directory
# This creates a "fingerprint" of the directory state that can be used to detect changes
#
# Usage: calculate_directory_checksum <directory> [file_pattern]
#
# Arguments:
#   directory     - Directory path to scan
#   file_pattern  - Optional file pattern (default: "*.md")
#
# Returns:
#   Single checksum string representing the state of all matching files
#   Empty string if no files found or directory doesn't exist
#
# Example:
#   checksum=$(calculate_directory_checksum "$HOME/.claude/commands" "*.md")
#   # Later...
#   new_checksum=$(calculate_directory_checksum "$HOME/.claude/commands" "*.md")
#   if [[ "$checksum" != "$new_checksum" ]]; then
#       echo "Directory contents changed!"
#   fi
calculate_directory_checksum() {
    local directory="$1"
    local file_pattern="${2:-*.md}"
    
    # Return empty string if directory doesn't exist
    if [[ ! -d "$directory" ]]; then
        return 0
    fi
    
    # Calculate composite checksum using cross-platform approach
    # This approach:
    # 1. Finds all files matching the pattern
    # 2. Calculates individual checksums 
    # 3. Sorts the results for consistent ordering
    # 4. Creates a single hash of all the sorted checksums
    local result
    if result=$(find "$directory" -name "$file_pattern" -type f -exec md5sum {} + 2>/dev/null | sort | md5sum 2>/dev/null); then
        # Linux: md5sum available
        echo "$result" | cut -d' ' -f1
    elif result=$(find "$directory" -name "$file_pattern" -type f -exec md5 {} + 2>/dev/null | sort | md5 2>/dev/null); then
        # macOS: md5 available  
        echo "$result" | rev | cut -d' ' -f1 | rev
    else
        # Neither available - return empty string
        return 0
    fi
}

# Calculate checksum of a single file
# Cross-platform wrapper for md5sum/md5
#
# Usage: calculate_file_checksum <file_path>
#
# Arguments:
#   file_path - Path to file
#
# Returns:
#   Checksum string of the file
#   Empty string if file doesn't exist or checksum calculation fails
calculate_file_checksum() {
    local file_path="$1"
    
    # Return empty string if file doesn't exist
    if [[ ! -f "$file_path" ]]; then
        return 0
    fi
    
    local result
    if result=$(md5sum "$file_path" 2>/dev/null); then
        # Linux: md5sum available
        echo "$result" | cut -d' ' -f1
    elif result=$(md5 "$file_path" 2>/dev/null); then
        # macOS: md5 available
        echo "$result" | rev | cut -d' ' -f1 | rev
    else
        # Neither available - return empty string
        return 0
    fi
}