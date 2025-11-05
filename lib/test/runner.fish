# Generic Test Runner
# Discovers and runs test files from a cases/ directory

# Check if required functions are available
if not functions -q pass
    echo "Error: Test assertions not loaded. Source assertions.fish before runner.fish"
    exit 1
end

# Temp file to collect all output
set -g TEMP_OUTPUT (mktemp)

# Default cleanup function (can be overridden)
function __test_cleanup
    cd /tmp 2>/dev/null
    rm -rf "$TEST_CASE_TEMP_DIR" 2>/dev/null
end

function __test_cleanup_all
    # No-op by default
end

function __test_setup_all
    # No-op by default
end

function __test_setup
    # No-op by default
end

# Allow projects to register custom cleanup (imperative API for advanced use)
function register_test_cleanup
    function __test_cleanup
        eval $argv
    end
end

function register_test_cleanup_all
    function __test_cleanup_all
        eval $argv
    end
end

function register_test_setup
    function __test_setup
        eval $argv
    end
end

# Auto-discover conventional hook files if they exist
if test -n "$TEST_DIR"
    # Option 1: Single hooks.fish file with special function names (preferred)
    if test -f "$TEST_DIR/hooks.fish"
        source "$TEST_DIR/hooks.fish"

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

        # Register before_all if defined
        if functions -q before_all
            function __test_setup_all
                before_all
            end
        end
    else
        # Option 2: Individual hook files (executed as scripts, not sourced)
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
end

# Run all tests in the cases directory
function run_tests
    set -l cases_dir $argv[1]

    if not test -d "$cases_dir"
        echo "Error: Test cases directory not found: $cases_dir"
        exit 1
    end

    # Run before-all setup
    __test_setup_all

    echo -e "$YELLOW"Running tests..."$NC\n"

    # Run test files from cases/ directory (recursively)
    for test_file in (find "$cases_dir" -name "*.fish" -type f | sort)
        # Generate test title from path (e.g., "flo/branch-mode.fish" -> "Flo > Branch Mode")
        set -l relative_path (string replace "$cases_dir/" "" "$test_file")
        set -l test_name (echo "$relative_path" | sed 's/\.fish$//' | tr '/' ' > ' | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) if($i!~/>/) $i=toupper(substr($i,1,1)) tolower(substr($i,2)); else $i=$i}1')

        # Filter tests by pattern if TEST_FILE_FILTER is set
        if test -n "$TEST_FILE_FILTER"
            # Case-insensitive substring match
            if not echo "$test_name" | grep -qi "$TEST_FILE_FILTER"
                continue
            end
        end

        # Extract and filter by tags (unless --all flag is set)
        if test "$TEST_RUN_ALL" != true
            set -l test_tags # Empty list by default (untagged)

            # Step 1: Static detection - look for tags declaration
            set -l tags_line (head -n 20 "$test_file" | grep -E '^tags\s+' | head -n 1)

            if test -n "$tags_line"
                # Step 2: Validation - ensure no code before tags
                # Get all lines before (not including) the tags line
                set -l before_tags (head -n 20 "$test_file" | sed '/^tags\s/Q' | grep -vE '^\s*(#|$)')

                if test (count $before_tags) -gt 0
                    echo -e "$RED""Error: Code found before 'tags' in $test_file""$NC"
                    echo "Tags must be the first non-blank, non-comment line"
                    exit 1
                end

                # Step 3: Controlled execution - extract tags safely
                begin
                    function tags
                        set -g TEST_CURRENT_TAGS $argv
                        return 0
                    end

                    source "$test_file" 2>/dev/null
                    set test_tags $TEST_CURRENT_TAGS
                end
            end

            # Step 4: Apply filtering logic
            set -l should_run false

            if test (count $TEST_TAG_FILTER) -eq 0
                # No tag filter: run only untagged tests
                if test (count $test_tags) -eq 0
                    set should_run true
                end
            else
                # Tag filter specified: check if test matches
                if contains untagged $TEST_TAG_FILTER; and test (count $test_tags) -eq 0
                    # Run untagged test if "untagged" in filter
                    set should_run true
                else
                    # Check if any test tag matches filter
                    for tag in $test_tags
                        if contains $tag $TEST_TAG_FILTER
                            set should_run true
                            break
                        end
                    end
                end
            end

            # Skip test if it doesn't match filter
            if test "$should_run" != true
                continue
            end
        end

        echo -e "\n$YELLOW""Test: $test_name""$NC"

        # Set up common test fixtures (tests can use or override)
        set -gx TEST_CASE_TEMP_DIR (mktemp -d)

        # Source and run the test (fish functions provide natural isolation)
        begin
            # Define tags as no-op since we already extracted them
            function tags
                # No-op: tags already extracted
            end

            # Run before_each setup
            __test_setup
            source "$test_file"
        end

        # Cleanup after test
        __test_cleanup
    end

    # Count passes, failures, and snapshot updates from output
    # Grep directly on file with pattern that includes ANSI codes
    set -l passed_count (grep -c "✓" "$TEMP_OUTPUT" 2>/dev/null | string trim)
    set -l failed_count (grep -c "✗" "$TEMP_OUTPUT" 2>/dev/null | string trim)
    set -l snapshots_count (grep -c "Updated snapshot:" "$TEMP_OUTPUT" 2>/dev/null | string trim)

    # Set to 0 if empty
    test -z "$passed_count"; and set passed_count 0
    test -z "$failed_count"; and set failed_count 0
    test -z "$snapshots_count"; and set snapshots_count 0

    set -g PASSED $passed_count
    set -g FAILED $failed_count
    set -l SNAPSHOTS_UPDATED $snapshots_count

    # Cleanup temp file
    rm "$TEMP_OUTPUT"

    # Summary
    echo ""
    echo "========================================"
    echo -e "$GREEN""Passed: $PASSED""$NC"
    if test $FAILED -gt 0
        echo -e "$RED""Failed: $FAILED""$NC"
    else
        echo -e "Failed: $FAILED"
    end
    if test $SNAPSHOTS_UPDATED -gt 0
        echo -e "$YELLOW""Snapshots updated: $SNAPSHOTS_UPDATED""$NC"
    end
    echo "========================================"

    # Run after-all cleanup
    __test_cleanup_all

    if test $FAILED -gt 0
        exit 1
    end

    exit 0
end
