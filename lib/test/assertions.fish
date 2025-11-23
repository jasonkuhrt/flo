# Generic Test Framework - Assertion Utilities
# Reusable test assertions for any fish test suite

# Colors
set -g RED '\033[0;31m'
set -g GREEN '\033[0;32m'
set -g YELLOW '\033[1;33m'
set -g NC '\033[0m' # No Color

# Test counters
set -g PASSED 0
set -g FAILED 0

# Command execution helper
# Runs a command and captures output for assertions
function run
    set -g RUN_OUTPUT (eval $argv 2>&1)
    set -g RUN_STATUS $status
    return $RUN_STATUS
end

# Core test result functions
# All assertion functions call fail/pass to report results
# Results are collected in TEMP_OUTPUT and counted by test runner

function fail --description "Report test assertion failure"
    set -l msg "$RED✗ Assertion: $argv[1]$NC"
    echo -e "$msg"
    if set -q TEMP_OUTPUT
        # Use printf to ensure newline is written correctly
        printf "%s\n" "$msg" >>"$TEMP_OUTPUT"
    end
    return 1
end

function pass --description "Report test assertion success"
    set -l msg "$GREEN✓ Assertion: $argv[1]$NC"
    echo -e "$msg"
    if set -q TEMP_OUTPUT
        # Use printf to ensure newline is written correctly
        printf "%s\n" "$msg" >>"$TEMP_OUTPUT"
    end
end

# Filesystem assertions

function assert_dir_exists
    set -l path $argv[1]
    set -l msg (test (count $argv) -ge 2; and echo $argv[2]; or echo "Directory exists: $path")

    if test -d "$path"
        pass "$msg"
    else
        fail "$msg"
    end
end

function assert_not_dir_exists
    set -l path $argv[1]
    set -l msg (test (count $argv) -ge 2; and echo $argv[2]; or echo "Directory does not exist: $path")

    if not test -d "$path"
        pass "$msg"
    else
        fail "$msg"
    end
end

function assert_file_exists
    set -l path $argv[1]
    set -l msg (test (count $argv) -ge 2; and echo $argv[2]; or echo "File exists: $path")

    if test -f "$path"
        pass "$msg"
    else
        fail "$msg"
    end
end

function assert_not_file_exists
    set -l path $argv[1]
    set -l msg (test (count $argv) -ge 2; and echo $argv[2]; or echo "File does not exist: $path")

    if not test -f "$path"
        pass "$msg"
    else
        fail "$msg"
    end
end

# Git assertions

function assert_git_branch_exists
    set -l branch $argv[1]
    set -l msg (test (count $argv) -ge 2; and echo $argv[2]; or echo "Branch exists: $branch")

    if git branch | string match -q "*$branch*"
        pass "$msg"
    else
        fail "$msg"
    end
end

function assert_not_git_branch_exists
    set -l branch $argv[1]
    set -l msg (test (count $argv) -ge 2; and echo $argv[2]; or echo "Branch does not exist: $branch")

    if not git branch | string match -q "*$branch*"
        pass "$msg"
    else
        fail "$msg"
    end
end

# Content assertions

# Core string assertion - expected, actual, message
function assert_string_contains
    set -l expected $argv[1]
    set -l actual $argv[2]
    set -l msg (test (count $argv) -ge 3; and echo $argv[3]; or echo "String contains: $expected")

    if string match -qi "*$expected*" "$actual"
        pass "$msg"
    else
        fail "$msg"
    end
end

function assert_not_string_contains
    set -l expected $argv[1]
    set -l actual $argv[2]
    set -l msg (test (count $argv) -ge 3; and echo $argv[3]; or echo "String does not contain: $expected")

    if not string match -qi "*$expected*" "$actual"
        pass "$msg"
    else
        fail "$msg"
    end
end

function assert_string_equals
    set -l expected $argv[1]
    set -l actual $argv[2]
    set -l msg (test (count $argv) -ge 3; and echo $argv[3]; or echo "String equals: $expected")

    if test "$actual" = "$expected"
        pass "$msg"
    else
        fail "$msg (expected: $expected, got: $actual)"
    end
end

function assert_not_string_equals
    set -l expected $argv[1]
    set -l actual $argv[2]
    set -l msg (test (count $argv) -ge 3; and echo $argv[3]; or echo "String does not equal: $expected")

    if test "$actual" != "$expected"
        pass "$msg"
    else
        fail "$msg"
    end
end

function assert_string_regex
    set -l pattern $argv[1]
    set -l actual $argv[2]
    set -l msg (test (count $argv) -ge 3; and echo $argv[3]; or echo "String matches regex: $pattern")

    if string match -qr "$pattern" "$actual"
        pass "$msg"
    else
        fail "$msg"
    end
end

function assert_not_string_regex
    set -l pattern $argv[1]
    set -l actual $argv[2]
    set -l msg (test (count $argv) -ge 3; and echo $argv[3]; or echo "String does not match regex: $pattern")

    if not string match -qr "$pattern" "$actual"
        pass "$msg"
    else
        fail "$msg"
    end
end

function assert_file_contains
    set -l file $argv[1]
    set -l pattern $argv[2]
    set -l msg (test (count $argv) -ge 3; and echo $argv[3]; or echo "File contains: $pattern")

    if grep -q "$pattern" "$file"
        pass "$msg"
    else
        fail "$msg"
    end
end

function assert_not_file_contains
    set -l file $argv[1]
    set -l pattern $argv[2]
    set -l msg (test (count $argv) -ge 3; and echo $argv[3]; or echo "File does not contain: $pattern")

    if grep -q "$pattern" "$file"
        fail "$msg"
    else
        pass "$msg"
    end
end

# Status assertions

function assert_success
    set -l msg (test (count $argv) -ge 1; and echo $argv[1]; or echo "Command succeeded")

    if test $status -eq 0
        pass "$msg"
    else
        fail "$msg"
    end
end

function assert_failure
    set -l msg (test (count $argv) -ge 1; and echo $argv[1]; or echo "Command failed")

    if test $status -ne 0
        pass "$msg"
    else
        fail "$msg"
    end
end

# Snapshot testing

function assert_snapshot
    set -l name $argv[1]
    set -l content $argv[2]
    set -l test_file (status filename)
    set -l snapshot_dir (dirname "$test_file")/__snapshots__
    set -l snapshot_file "$snapshot_dir/"(basename "$test_file" .fish)".$name.txt"

    mkdir -p "$snapshot_dir"

    if not test -f "$snapshot_file"
        echo "$content" >"$snapshot_file"
        pass "Created snapshot: $name"
        return 0
    end

    if echo "$content" | diff -q - "$snapshot_file" >/dev/null 2>&1
        pass "Snapshot matches: $name"
    else
        # Snapshot mismatch - update if flag is set
        if test "$UPDATE_SNAPSHOTS" = true
            echo "$content" >"$snapshot_file"
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
        end
    end
end

# Spy system for mocking commands

function spy_on
    set -l cmd $argv[1]
    set -l spy_dir "$TEST_CASE_TEMP_DIR/.spies"
    set -l log_dir "$spy_dir/logs"
    set -l log_file "$log_dir/$cmd.log"

    # Create a Fish function that overrides the command
    # This is more reliable than PATH manipulation for Fish builtins/commands
    # The function creates its log directory on first call (survives setup_temp_repo cleanup)
    eval "
    function $cmd --description 'Spy for $cmd'
        mkdir -p '$log_dir' 2>/dev/null
        echo \$argv >> '$log_file'
        return 0
    end
    "
end

function spy_assert_called
    set -l cmd $argv[1]
    set -l pattern ""
    test (count $argv) -ge 2; and set pattern $argv[2]
    set -l log_file "$TEST_CASE_TEMP_DIR/.spies/logs/$cmd.log"

    if not test -f "$log_file"
        fail "Spy '$cmd' was never called (log not found)"
        return 1
    end

    set -l call_count (wc -l < "$log_file" | string trim)
    if test $call_count -eq 0
        fail "Spy '$cmd' was never called (empty log)"
        return 1
    end

    if test -n "$pattern"
        if not grep -q "$pattern" "$log_file"
            fail "Spy '$cmd' was called but never with args matching: $pattern"
            return 1
        end
        pass "Spy '$cmd' was called with: $pattern"
    else
        pass "Spy '$cmd' was called"
    end
end

function spy_assert_called_not
    set -l cmd $argv[1]
    set -l log_file "$TEST_CASE_TEMP_DIR/.spies/logs/$cmd.log"

    if test -f "$log_file"; and test -s "$log_file"
        set -l calls (cat "$log_file")
        fail "Spy '$cmd' should not be called, but was: $calls"
        return 1
    end

    pass "Spy '$cmd' was not called"
end

function spy_get_calls
    set -l cmd $argv[1]
    set -l log_file "$TEST_CASE_TEMP_DIR/.spies/logs/$cmd.log"

    if test -f "$log_file"
        cat "$log_file"
    end
end

# Output assertions (use $RUN_OUTPUT from run helper)

function assert_output_contains
    set -l pattern $argv[1]
    set -l msg (test (count $argv) -ge 2; and echo $argv[2]; or echo "Output contains: $pattern")

    if string match -qi "*$pattern*" "$RUN_OUTPUT"
        pass "$msg"
    else
        fail "$msg"
    end
end

function assert_output_not_contains
    set -l pattern $argv[1]
    set -l msg (test (count $argv) -ge 2; and echo $argv[2]; or echo "Output does not contain: $pattern")

    if not string match -qi "*$pattern*" "$RUN_OUTPUT"
        pass "$msg"
    else
        fail "$msg"
    end
end
