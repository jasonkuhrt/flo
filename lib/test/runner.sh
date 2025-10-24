#!/bin/bash

# Generic Test Runner
# Discovers and runs test files from a cases/ directory

# Check if required functions are available
if ! declare -f pass >/dev/null 2>&1; then
    echo "Error: Test assertions not loaded. Source assertions.sh before runner.sh"
    exit 1
fi

# Temp file to collect all output
TEMP_OUTPUT=$(mktemp)

# Default cleanup function (can be overridden)
__test_cleanup() {
    cd /tmp 2>/dev/null
    rm -rf "$TEMP_REPO" 2>/dev/null
}

__test_cleanup_all() {
    :  # No-op by default
}

__test_setup_all() {
    :  # No-op by default
}

# Allow projects to register custom cleanup (imperative API for advanced use)
register_test_cleanup() {
    __test_cleanup() {
        "$@"
    }
}

register_test_cleanup_all() {
    __test_cleanup_all() {
        "$@"
    }
}

# Auto-discover conventional hook files if they exist
if [[ -n "$TEST_DIR" ]]; then
    # Option 1: Single hooks.sh file with special function names (preferred)
    if [[ -f "$TEST_DIR/hooks.sh" ]]; then
        source "$TEST_DIR/hooks.sh"

        # Register after_each if defined
        if declare -f after_each >/dev/null 2>&1; then
            register_test_cleanup after_each
        fi

        # Register after_all if defined
        if declare -f after_all >/dev/null 2>&1; then
            __test_cleanup_all() {
                after_all
            }
        fi

        # Register before_all if defined
        if declare -f before_all >/dev/null 2>&1; then
            __test_setup_all() {
                before_all
            }
        fi
    else
        # Option 2: Individual hook files (executed as scripts, not sourced)
        if [[ -f "$TEST_DIR/before_all.sh" ]]; then
            __test_setup_all() {
                bash "$TEST_DIR/before_all.sh"
            }
        fi

        if [[ -f "$TEST_DIR/after_each.sh" ]]; then
            register_test_cleanup "bash $TEST_DIR/after_each.sh"
        fi

        if [[ -f "$TEST_DIR/after_all.sh" ]]; then
            __test_cleanup_all() {
                bash "$TEST_DIR/after_all.sh"
            }
        fi
    fi
fi

# Run all tests in the cases directory
run_tests() {
    local cases_dir="$1"

    if [[ ! -d "$cases_dir" ]]; then
        echo "Error: Test cases directory not found: $cases_dir"
        exit 1
    fi

    # Run before-all setup
    __test_setup_all

    echo -e "${YELLOW}Running tests...${NC}\n"

    # Run test files from cases/ directory (recursively)
    while IFS= read -r -d '' test_file; do
        # Generate test title from path (e.g., "flo/branch-mode.sh" -> "Flo > Branch Mode")
        relative_path="${test_file#$cases_dir/}"
        test_name=$(echo "$relative_path" | sed 's/\.sh$//' | tr '/' ' > ' | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) if($i!~/>/) $i=toupper(substr($i,1,1)) tolower(substr($i,2)); else $i=$i}1')
        echo -e "\n${YELLOW}Test: $test_name${NC}"

        # Set up common test fixtures (tests can use or override)
        export TEMP_REPO=$(mktemp -d)

        # Set up cleanup trap for this test
        trap '__test_cleanup; trap - EXIT' EXIT

        # Source and run the test
        source "$test_file"

        # Cleanup after test
        __test_cleanup
        trap - EXIT
    done < <(find "$cases_dir" -name "*.sh" -type f -print0 | sort -z)

    # Count passes, failures, and snapshot updates from output (strip ANSI codes first)
    local stripped_output=$(sed 's/\x1b\[[0-9;]*m//g' "$TEMP_OUTPUT")
    PASSED=$(echo "$stripped_output" | grep -c "^✓" 2>/dev/null | tr -d '\n' || echo 0)
    FAILED=$(echo "$stripped_output" | grep -c "^✗" 2>/dev/null | tr -d '\n' || echo 0)
    local SNAPSHOTS_UPDATED=$(echo "$stripped_output" | grep -c "Updated snapshot:" 2>/dev/null | tr -d '\n' || echo 0)

    # Cleanup temp file
    rm "$TEMP_OUTPUT"

    # Summary
    echo ""
    echo "========================================"
    echo -e "${GREEN}Passed: $PASSED${NC}"
    if [[ $FAILED -gt 0 ]]; then
        echo -e "${RED}Failed: $FAILED${NC}"
    else
        echo -e "Failed: $FAILED"
    fi
    if [[ $SNAPSHOTS_UPDATED -gt 0 ]]; then
        echo -e "${YELLOW}Snapshots updated: $SNAPSHOTS_UPDATED${NC}"
    fi
    echo "========================================"

    # Run after-all cleanup
    __test_cleanup_all

    if [[ $FAILED -gt 0 ]]; then
        exit 1
    fi

    exit 0
}
