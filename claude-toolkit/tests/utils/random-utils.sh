#!/bin/bash
# random-utils.sh - Test utilities for generating random data
#
# Purpose: Provides functions for generating random data in test environments
# Dependencies: None (uses system utilities when available, provides fallbacks)
# Usage: Source this file in test scripts that need random data generation

# generate_uuid - Generates a UUID using available system tools or fallback
generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen
    elif [[ -f /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
    else
        # Fallback: generate a pseudo-random UUID-like string
        printf '%08x-%04x-%04x-%04x-%012x' $RANDOM $RANDOM $RANDOM $RANDOM $RANDOM$RANDOM
    fi
}

# generate_random_site - Generates a random site URL for testing network failures
generate_random_site() {
    local uuid
    uuid=$(generate_uuid)
    printf 'https://nonexistent-%s.invalid' "$uuid"
}