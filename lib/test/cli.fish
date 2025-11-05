#!/usr/bin/env fish

# Test Framework CLI
# Discovers and runs tests automatically

# Set up CLI framework for auto-parsing
set -l test_dir (dirname (status filename))
set -l flo_dir (dirname (dirname $test_dir))

# Source CLI framework (single entrypoint)
source "$flo_dir/functions/__flo_lib_cli_main.fish"

# Set minimal framework state for command discovery
set -g __cli_dir $test_dir
set -g __cli_name test

# Parse arguments using framework auto-parsing
__cli_parse_args test $argv
or begin
    echo "Error: Invalid arguments"
    echo "Usage: lib/test/cli [--update|-u] [--file|-f PATTERN] [--tags TAG...] [--all] [--help|-h] [PATTERN]"
    exit 1
end

# Show help if requested
if set -q _flag_help
    set -l doc_file "$test_dir/test.md"
    __cli_render_command_help test "$doc_file"
    exit 0
end

# Set global variables from parsed flags
set -g UPDATE_SNAPSHOTS false
set -g TEST_FILE_FILTER ""
set -g TEST_TAG_FILTER
set -g TEST_RUN_ALL false

if set -q _flag_update
    set -g UPDATE_SNAPSHOTS true
end

if set -q _flag_all
    set -g TEST_RUN_ALL true
end

if set -q _flag_file
    set -g TEST_FILE_FILTER $_flag_file
end

if set -q _flag_tags
    set -g TEST_TAG_FILTER $_flag_tags
end

# Use remaining positional args as filter pattern (if --file not used)
if test (count $argv) -gt 0; and test -z "$TEST_FILE_FILTER"
    set -g TEST_FILE_FILTER (string join " " $argv)
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
