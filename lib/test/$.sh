#!/bin/bash

# Test Framework - Single Entry Point
# Source this file to load the complete test framework

# Get the directory where this script is located
FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load core framework modules
source "$FRAMEWORK_DIR/assertions.sh"
source "$FRAMEWORK_DIR/runner.sh"

# Auto-discover project root by looking for test/ or tests/ directory
__find_test_dir() {
    local current_dir="$1"
    while [[ "$current_dir" != "/" ]]; do
        if [[ -d "$current_dir/test" ]]; then
            echo "$current_dir/test"
            return 0
        elif [[ -d "$current_dir/tests" ]]; then
            echo "$current_dir/tests"
            return 0
        fi
        current_dir="$(dirname "$current_dir")"
    done
    return 1
}

# Auto-discover and source helpers.sh if it exists
# Convention: helpers.sh should be in test/ or tests/ directory
if [[ -n "${BASH_SOURCE[1]}" ]]; then
    CALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    TEST_DIR=$(__find_test_dir "$CALLER_DIR")

    if [[ -n "$TEST_DIR" ]]; then
        # Export for use in test scripts
        export TEST_DIR
        export PROJECT_ROOT="$(dirname "$TEST_DIR")"

        # Source helpers.sh if it exists
        if [[ -f "$TEST_DIR/helpers.sh" ]]; then
            source "$TEST_DIR/helpers.sh"
        fi
    fi
fi
