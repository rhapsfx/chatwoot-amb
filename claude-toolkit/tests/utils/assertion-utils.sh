#!/bin/bash
# assertion-utils.sh - Enhanced assertion utilities for CCTK testing
# Provides domain-specific assertions following functional programming principles

set -euo pipefail

# Colors for output
RED='\033[0;31m'
NC='\033[0m' # No Color

# Internal: format a failure with *caller* site (file:line of the assert call)
_assert_fail() {
    # call stack: [0]=_assert_fail, [1]=assert_*, [2]=<call site>
    local file="${BASH_SOURCE[2]##*/}"
    local line="${BASH_LINENO[1]}"
    local msg="$1"; shift
    printf '%bASSERTION FAILED [%s:%s]: %b%b\n' "$RED" "$file" "$line" "$msg" "$NC" >&"$ASSERT_FD"
    exit 1
}

# Assert that a file is executable
assert_file_executable() {
    local file_path="$1"
    local message="${2:-File should be executable}"
    
    if [[ -x "$file_path" ]]; then
        return 0
    else
        _assert_fail "$message: $file_path"
    fi
}

# Assert that a symlink exists
assert_symlink_exists() {
    local symlink_path="$1"
    local message="${2:-Symlink should exist}"
    
    if [[ -L "$symlink_path" ]]; then
        return 0
    else
        _assert_fail "$message: $symlink_path"
    fi
}

# Assert that condition evaluates to true
assert_true() {
    local condition="$1"
    local message="${2:-Condition should be true}"
    
    if eval "$condition"; then
        return 0
    else
        _assert_fail "$message: $condition"
    fi
}

# Assert that first value is greater than second value
assert_greater_than() {
    local first="$1"
    local second="$2"
    local message="${3:-First value should be greater than second}"
    
    # Check if both values are numeric
    if ! [[ "$first" =~ ^[0-9]+$ ]] || ! [[ "$second" =~ ^[0-9]+$ ]]; then
        _assert_fail "$message: non-numeric values [$first] > [$second]"
        return
    fi
    
    if [[ "$first" -gt "$second" ]]; then
        return 0
    else
        _assert_fail "$message: expected [$first] > [$second]"
    fi
}

# Assert that values are not equal
assert_not_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should not be equal}"
    
    if [[ "$expected" != "$actual" ]]; then
        return 0
    else
        _assert_fail "$message: expected != [$expected], got [$actual]"
    fi
}

# Assert that file does not exist
assert_file_not_exists() {
    local file_path="$1"
    local message="${2:-File should not exist}"
    
    if [[ ! -f "$file_path" ]]; then
        return 0
    else
        _assert_fail "$message: $file_path"
    fi
}

# Assert that directory does not exist
assert_directory_not_exists() {
    local dir_path="$1"
    local message="${2:-Directory should not exist}"
    
    if [[ ! -d "$dir_path" ]]; then
        return 0
    else
        _assert_fail "$message: $dir_path"
    fi
}

# Assert that values are equal
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"
    
    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        _assert_fail "$message: expected == [$expected], got [$actual]"
    fi
}

# Assert that string contains substring
assert_contains() {
    local substring="$1"
    local string="$2"
    local message="${3:-String should contain substring}"
    
    if [[ "$string" == *"$substring"* ]]; then
        return 0
    else
        _assert_fail "$message: expected [$string] to contain [$substring]"
    fi
}

# Assert that string does not contain substring
assert_not_contains() {
    local substring="$1"
    local string="$2"
    local message="${3:-String should not contain substring}"
    
    if [[ "$string" != *"$substring"* ]]; then
        return 0
    else
        _assert_fail "$message: expected [$string] to not contain [$substring]"
    fi
}

# Assert that string matches regex pattern
assert_matches() {
    local pattern="$1"
    local string="$2"
    local message="${3:-String should match regex pattern}"
    
    if [[ "$string" =~ $pattern ]]; then
        return 0
    else
        _assert_fail "$message: expected [$string] to match pattern [$pattern]"
    fi
}

# Assert that string does not match regex pattern
assert_not_matches() {
    local pattern="$1"
    local string="$2"
    local message="${3:-String should not match regex pattern}"
    
    if [[ ! "$string" =~ $pattern ]]; then
        return 0
    else
        _assert_fail "$message: expected [$string] to not match pattern [$pattern]"
    fi
}

# Assert exit code matches expected
assert_exit_code() {
    local expected_code="$1"
    local actual_code="$2"
    local message="${3:-Exit code should match expected}"
    
    if [[ "$expected_code" == "$actual_code" ]]; then
        return 0
    else
        _assert_fail "$message: expected rc=$expected_code, got rc=$actual_code"
    fi
}

# Assert that file exists
assert_file_exists() {
    local file_path="$1"
    local message="${2:-File should exist}"
    
    if [[ -f "$file_path" ]]; then
        return 0
    else
        _assert_fail "$message: $file_path"
    fi
}

# Assert that directory exists
assert_directory_exists() {
    local dir_path="$1"
    local message="${2:-Directory should exist}"
    
    if [[ -d "$dir_path" ]]; then
        return 0
    else
        _assert_fail "$message: $dir_path"
    fi
}

# assert_command_succeeds [message] -- cmd arg...
assert_command_succeeds() {
  local msg="Command should succeed"
  if [[ "$1" != "--" ]]; then msg="$1"; shift; fi
  [[ "$1" == "--" ]] || { _assert_fail "usage: assert_cmd_ok_t [message] -- cmd ..."; return; }
  shift

  local outf errf rc
  outf="$(mktemp "${TMPDIR:-/tmp}/assert.out.XXXXXX")" || { _assert_fail "mktemp failed"; return; }
  errf="$(mktemp "${TMPDIR:-/tmp}/assert.err.XXXXXX")" || { rm -f "$outf"; _assert_fail "mktemp failed"; return; }

  # Run once: mirror to caller AND capture to files
  { "$@" 2> >(tee "$errf" >&2) | tee "$outf"; }
  # Status of the *command* (stage 0), not tee
  rc=${PIPESTATUS[0]}

  if (( rc == 0 )); then
    rm -f "$outf" "$errf"
    return 0
  fi

  # Read captured outputs only on failure
  local out err
  out="$(<"$outf")"; err="$(<"$errf")"
  rm -f "$outf" "$errf"
  _assert_fail "$msg: $* (rc=$rc)\nSTDOUT +++\n${out}\n---\nSTDERR +++\n${err}\n---"
}

# assert_command_fails [expected_rc] [message] -- cmd arg...
# If expected_rc omitted, any non-zero is accepted.
assert_command_fails() {
  local expected_rc="" msg="Command should fail"
  if [[ "$1" =~ ^[0-9]+$ ]]; then expected_rc="$1"; shift; fi
  if [[ "$1" != "--" && -n "$1" ]]; then msg="$1"; shift; fi
  [[ "$1" == "--" ]] || { _assert_fail "usage: assert_cmd_fail_t [expected_rc] [message] -- cmd ..."; return; }
  shift

  local outf errf rc
  outf="$(mktemp "${TMPDIR:-/tmp}/assert.out.XXXXXX")" || { _assert_fail "mktemp failed"; return; }
  errf="$(mktemp "${TMPDIR:-/tmp}/assert.err.XXXXXX")" || { rm -f "$outf"; _assert_fail "mktemp failed"; return; }

  { "$@" 2> >(tee "$errf" >&2) | tee "$outf"; }
  rc=${PIPESTATUS[0]}

  local out err
  out="$(<"$outf")"; err="$(<"$errf")"
  rm -f "$outf" "$errf"

  if (( rc == 0 )); then
    _assert_fail "$msg: expected failure but succeeded: $*\nSTDOUT +++\n${out}\n---\nSTDERR +++\n${err}\n---"
    return
  fi
  if [[ -n "$expected_rc" && "$rc" -ne "$expected_rc" ]]; then
    _assert_fail "$msg: expected rc=$expected_rc, got rc=$rc: $*\nSTDOUT +++\n${out}\n---\nSTDERR +++\n${err}\n---"
    return
  fi
  return 0
}

# Assert that file contains expected content
assert_file_contains() {
    local file_path="$1"
    local expected_content="$2"
    local message="${3:-File should contain expected content}"
    
    if [[ ! -f "$file_path" ]]; then
        _assert_fail "$message: file does not exist: $file_path"
        return
    fi
    
    if grep -q -- "$expected_content" "$file_path"; then
        return 0
    else
        _assert_fail "$message: [$expected_content] not found in $file_path"
    fi
}

# Assert that file does not contain unexpected content
assert_file_not_contains() {
    local file_path="$1"
    local unexpected_content="$2"
    local message="${3:-File should not contain unexpected content}"
    
    if [[ ! -f "$file_path" ]]; then
        return 0
    fi
    
    if ! grep -q -- "$unexpected_content" "$file_path"; then
        return 0
    else
        _assert_fail "$message: [$unexpected_content] found in $file_path"
    fi
}

# Assert that environment variable is set
assert_env_var_set() {
    local var_name="$1"
    local expected_value="${2:-}"
    local message="${3:-Environment variable should be set}"
    
    if [[ -z "${!var_name:-}" ]]; then
        _assert_fail "$message: $var_name not set"
        return
    fi
    
    if [[ -n "$expected_value" ]] && [[ "${!var_name}" != "$expected_value" ]]; then
        _assert_fail "$message: $var_name expected [$expected_value], got [${!var_name}]"
        return
    fi
    
    return 0
}

# Assert that environment variable is not set
assert_env_var_not_set() {
    local var_name="$1"
    local message="${2:-Environment variable should not be set}"
    
    if [[ -z "${!var_name:-}" ]]; then
        return 0
    else
        _assert_fail "$message: $var_name is set to [${!var_name}]"
    fi
}

# Pick a free FD and duplicate current stderr to it, store the number in ASSERT_FD.
init_assert_fd() {
  local fd
  for fd in {8..32}; do
    # Probe: is $fd already open? redirect stderr first, then try to dup to $fd.
    # In Bash 3.2 we must use eval for $fd in a redirection.
    if eval ': 2>/dev/null >&'"$fd"; then
      continue  # $fd is open; skip it
    fi

    # Try to reserve this fd by duplicating current stderr (2) into it
    if eval 'exec '"$fd"'>&2'; then
      ASSERT_FD=$fd
      export ASSERT_FD
      return 0
    fi
  done
  printf 'FATAL: no free FD for ASSERT_FD\n' >&2
  return 1
}

init_assert_fd
# Export assertion functions
export -f assert_directory_not_exists
export -f assert_env_var_not_set
export -f assert_env_var_set
export -f assert_file_contains
export -f assert_file_executable
export -f assert_file_not_contains
export -f assert_file_not_exists
export -f assert_greater_than
export -f assert_not_equals
export -f assert_symlink_exists
export -f assert_true
export -f assert_equals
export -f assert_contains
export -f assert_not_contains
export -f assert_matches
export -f assert_not_matches
export -f assert_exit_code
export -f assert_file_exists
export -f assert_directory_exists
export -f assert_command_succeeds
export -f assert_command_fails
