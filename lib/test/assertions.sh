#!/bin/bash

# Generic Test Framework - Assertion Utilities
# Reusable test assertions for any bash test suite

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
PASSED=0
FAILED=0

# Core test result functions

fail() {
    local msg="${RED}✗ $1${NC}"
    echo -e "$msg"
    [[ -n "$TEMP_OUTPUT" ]] && echo -e "$msg" >> "$TEMP_OUTPUT"
    return 1
}

pass() {
    local msg="${GREEN}✓ $1${NC}"
    echo -e "$msg"
    [[ -n "$TEMP_OUTPUT" ]] && echo -e "$msg" >> "$TEMP_OUTPUT"
}

# Filesystem assertions

assert_dir_exists() {
    if [[ -d "$1" ]]; then
        pass "Directory exists: $1"
    else
        fail "Directory does not exist: $1"
    fi
}

assert_dir_not_exists() {
    if [[ ! -d "$1" ]]; then
        pass "$2"
    else
        fail "$2"
    fi
}

assert_file_exists() {
    if [[ -f "$1" ]]; then
        pass "File exists: $1"
    else
        fail "File does not exist: $1"
    fi
}

assert_file_not_exists() {
    if [[ ! -f "$1" ]]; then
        pass "$2"
    else
        fail "$2"
    fi
}

# Content assertions

assert_contains() {
    if echo "$1" | grep -q "$2"; then
        pass "Output contains: $2"
    else
        fail "Output does not contain: $2"
    fi
}

assert_output_contains() {
    if echo "$1" | grep -q "$2"; then
        pass "$3"
    else
        fail "$3"
    fi
}

assert_file_contains() {
    if grep -q "$2" "$1"; then
        pass "$3"
    else
        fail "$3"
    fi
}

# Status assertions

assert_success() {
    if [[ $? -eq 0 ]]; then
        pass "$1"
    else
        fail "$1"
    fi
}

# Snapshot testing

assert_snapshot() {
    local name="$1"
    local content="$2"
    local snapshot_dir="${BASH_SOURCE[1]%/*}/__snapshots__"
    local snapshot_file="$snapshot_dir/$(basename "${BASH_SOURCE[1]}" .sh).$name.txt"

    mkdir -p "$snapshot_dir"

    if [[ ! -f "$snapshot_file" ]]; then
        echo "$content" > "$snapshot_file"
        pass "Created snapshot: $name"
        return 0
    fi

    if diff -q <(echo "$content") "$snapshot_file" >/dev/null 2>&1; then
        pass "Snapshot matches: $name"
    else
        # Snapshot mismatch - update if flag is set
        if [[ "${UPDATE_SNAPSHOTS:-false}" == "true" ]]; then
            echo "$content" > "$snapshot_file"
            pass "Updated snapshot: $name"
        else
            fail "Snapshot mismatch: $name"
            echo "Expected:"
            cat "$snapshot_file"
            echo ""
            echo "Actual:"
            echo "$content"
            echo ""
            echo "Run with --update to update snapshots"
            return 1
        fi
    fi
}
