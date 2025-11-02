#!/usr/bin/env fish

# Test Framework CLI
# Discovers and runs tests automatically

# Parse flags and positional arguments
set -g UPDATE_SNAPSHOTS false
set -g TEST_FILE_FILTER ""
set -l positional_args

set -l i 1
while test $i -le (count $argv)
    switch $argv[$i]
        case -u --update
            set -g UPDATE_SNAPSHOTS true
        case -f --file
            set i (math $i + 1)
            set -g TEST_FILE_FILTER $argv[$i]
        case '--*' '-*'
            echo "Unknown option: $argv[$i]"
            echo "Usage: lib/test/cli [--update|-u] [PATTERN]"
            exit 1
        case '*'
            # Positional argument - treat as filter pattern
            set -a positional_args $argv[$i]
    end
    set i (math $i + 1)
end

# Use positional args as filter if provided (and --file wasn't used)
if test (count $positional_args) -gt 0; and test -z "$TEST_FILE_FILTER"
    set -g TEST_FILE_FILTER (string join " " $positional_args)
end

# Find project root by looking for test/ or tests/ directory
function find_test_dir
    set -l current_dir (pwd)
    while test "$current_dir" != /
        if test -d "$current_dir/test"
            echo "$current_dir/test"
            return 0
        else if test -d "$current_dir/tests"
            echo "$current_dir/tests"
            return 0
        end
        set current_dir (dirname "$current_dir")
    end

    echo "Error: No test/ or tests/ directory found" >&2
    return 1
end

# Get framework directory
set -l FRAMEWORK_DIR (dirname (status filename))

# Find test directory
set -gx TEST_DIR (find_test_dir)
if test $status -ne 0
    exit 1
end

# Export for use in framework
set -gx PROJECT_ROOT (dirname "$TEST_DIR")

# Load framework modules
source "$FRAMEWORK_DIR/assertions.fish"
source "$FRAMEWORK_DIR/runner.fish"

# Load helpers if exists
if test -f "$TEST_DIR/helpers.fish"
    source "$TEST_DIR/helpers.fish"
end

# Load hooks if exists
if test -f "$TEST_DIR/hooks.fish"
    source "$TEST_DIR/hooks.fish"

    # Register before_all if defined
    if functions -q before_all
        function __test_setup_all
            before_all
        end
    end

    # Register before_each if defined
    if functions -q before_each
        function __test_setup
            before_each
        end
    end

    # Register after_each if defined
    if functions -q after_each
        function __test_cleanup
            after_each
        end
    end

    # Register after_all if defined
    if functions -q after_all
        function __test_cleanup_all
            after_all
        end
    end
else
    # Fall back to individual hook files
    if test -f "$TEST_DIR/before_all.fish"
        function __test_setup_all
            fish "$TEST_DIR/before_all.fish"
        end
    end

    if test -f "$TEST_DIR/after_each.fish"
        function __test_cleanup
            fish "$TEST_DIR/after_each.fish"
        end
    end

    if test -f "$TEST_DIR/after_all.fish"
        function __test_cleanup_all
            fish "$TEST_DIR/after_all.fish"
        end
    end
end

# Run tests
run_tests "$TEST_DIR/cases"
