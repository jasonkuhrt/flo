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
        # Use Fish string functions for portability (BSD awk doesn't handle the original awk)
        set -l test_name_parts (string replace '.fish' '' $relative_path | string split '/')
        set -l test_name_formatted
        for part in $test_name_parts
            # Split on hyphens and title case each word
            set -l words (string split '-' $part)
            set -l titled_words
            for word in $words
                set -l first (string sub -l 1 $word | string upper)
                set -l rest (string sub -s 2 $word)
                set -a titled_words "$first$rest"
            end
            set -a test_name_formatted (string join ' ' $titled_words)
        end
        set -l test_name (string join ' > ' $test_name_formatted)

        # Filter tests by pattern if TEST_FILE_FILTER is set
        if test -n "$TEST_FILE_FILTER"
            # Normalize both for matching: lowercase, replace hyphens with spaces
            set -l norm_test_name (string lower (string replace -a '-' ' ' $test_name))
            set -l norm_filter (string lower (string replace -a '-' ' ' $TEST_FILE_FILTER))
            # Case-insensitive substring match
            if not string match -q "*$norm_filter*" $norm_test_name
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
                # Get line number where tags appears
                set -l tags_line_num (grep -n '^tags\s' "$test_file" | head -1 | cut -d: -f1)
                # Get all lines before (not including) the tags line, filter out comments/blank
                set -l before_line (math $tags_line_num - 1)
                set -l before_tags (head -n $before_line "$test_file" | grep -vE '^\s*(#|$)')

                if test (count $before_tags) -gt 0
                    echo -e "$RED""Error: Code found before 'tags' in $test_file""$NC"
                    echo "Tags must be the first non-blank, non-comment line"
                    exit 1
                end

                # Step 3: Controlled execution - extract tags safely
                # Source file in subprocess where tags() can exit to stop execution
                set -l tags_output (fish -c "
                    function tags
                        echo \$argv
                        exit 0  # Exit subprocess when tags called
                    end
                    source '$test_file' 2>/dev/null
                ")
                # Split the output into array
                if test -n "$tags_output"
                    set test_tags (string split ' ' -- $tags_output)
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

            # CRITICAL: Start tests in temp dir to prevent file pollution in project root
            # If test cd commands fail, files will be created in temp dir instead of project root
            cd "$TEST_CASE_TEMP_DIR"

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
