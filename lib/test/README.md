# Generic Test Framework

Reusable test utilities for fish test suites.

## Quick Start

```sh
lib/test/cli                       # Run all tests
lib/test/cli --update              # Update snapshots (on mismatch, overwrites)
lib/test/cli --file pattern        # Run tests matching pattern (case-insensitive)
```

**Examples**:
```sh
lib/test/cli --file gitignore      # Run only tests with "gitignore" in name
lib/test/cli --file "flo end"      # Run all "flo end" tests
```

**Makefile**: `test: @lib/test/cli $(ARGS)`

**Auto-discovered files**:
- `test/helpers.fish` - Project helpers (`$TEST_DIR`, `$PROJECT_ROOT` available)
- `test/hooks.fish` - Lifecycle hooks (`before_all()`, `before_each()`, `after_each()`, `after_all()`)
- `test/cases/**/*.fish` - Test files (nested directories supported)

## Assertions

**Naming Convention:**
- All assertions follow `assert_*` and `assert_not_*` pattern
- Every assertion must have a negative variant
- Last parameter is always optional message with sensible default

**Results**: `pass(msg)`, `fail(msg)`

**Files**:
- `assert_dir_exists(path, [msg])`, `assert_not_dir_exists(path, [msg])`
- `assert_file_exists(path, [msg])`, `assert_not_file_exists(path, [msg])`
- `assert_file_contains(file, pattern, [msg])`, `assert_not_file_contains(file, pattern, [msg])`

**Git**:
- `assert_git_branch_exists(branch, [msg])`, `assert_not_git_branch_exists(branch, [msg])`

**Strings**:
- `assert_string_contains(expected, actual, [msg])`, `assert_not_string_contains(expected, actual, [msg])` - Case-insensitive substring match
- `assert_string_equals(expected, actual, [msg])`, `assert_not_string_equals(expected, actual, [msg])` - Exact match
- `assert_string_regex(pattern, actual, [msg])`, `assert_not_string_regex(pattern, actual, [msg])` - Regex match

**Files (content)**:
- `assert_file_contains(file, pattern, [msg])`, `assert_not_file_contains(file, pattern, [msg])`

**Status**:
- `assert_success([msg])`, `assert_failure([msg])`

**Snapshots**:
- `assert_snapshot(name, content)` - Creates/compares snapshots in `__snapshots__/`

## Hooks

**Conventional** (auto-sourced from `test/hooks.fish`):
- `before_all()` - Runs once before all tests
- `before_each()` - Runs before each test (perfect for setting up spies or resetting state)
- `after_each()` - Runs after each test
- `after_all()` - Runs once after all tests

**Imperative** (for dynamic behavior):
- `register_test_setup(fn)` - Register custom before_each behavior
- `register_test_cleanup(fn)` - Register custom after_each behavior
- `register_test_cleanup_all(fn)` - Register custom after_all behavior

**Example `test/hooks.fish`:**
```fish
function before_each
    # Setup fresh spies for every test
    spy_on docker
    spy_on kubectl
end

function after_each
    # Cleanup temp files
    rm -rf "$TEST_CASE_TEMP_DIR"
end
```

## Variables

- `$TEST_CASE_TEMP_DIR` - Unique temp directory per test (auto-cleaned)
- `$TEST_DIR`, `$PROJECT_ROOT` - Auto-discovered paths
- `$PASSED`, `$FAILED` - Test counts

## Test Execution & Isolation

### How Tests Run

Each test case file (`.fish`) in `test/cases/` is:
1. **Discovered automatically** - Nested directories supported
2. **Executed with function scope isolation** - Isolated from other tests and the runner
3. **Given a unique temp directory** - `$TEST_CASE_TEMP_DIR` is created and cleaned up automatically
4. **Named from its path** - `test/cases/flo/branch-mode.fish` → "Flo > Branch Mode"

### Isolation Guarantees

Each test runs with isolated environment via fish's `begin/end` blocks:

- **PATH modifications** don't leak across tests
- **Variables** set in test don't affect other tests
- **Function scope** provides natural isolation
- **`$TEST_CASE_TEMP_DIR`** is unique per test and automatically cleaned up

This ensures tests are independent and can safely modify their environment.

### Failure Handling

**Test failures:**
- Individual assertions call `fail(msg)` which prints an error and returns non-zero
- Failed assertions don't stop the test - remaining assertions still run
- Tests continue even if some assertions fail

**Critical failures:**
- If a test calls `exit`, the entire test suite exits (fish limitation)
- Write tests to avoid `exit` calls - use `return` within functions instead
- Cleanup hooks (`after_each`) run after each test completes

**Exit codes:**
- `0` - All tests passed
- `1` - One or more tests failed

**Output:**
- Summary shows passed/failed counts
- Failed assertions display in red with ✗
- Passed assertions display in green with ✓

## Spy System

Mock commands to verify they were called with expected arguments:

**Functions:**
- `spy_on <cmd>` - Create a spy for the command
- `spy_assert_called <cmd> [pattern]` - Assert command was called, optionally with args matching pattern
- `spy_assert_called_not <cmd>` - Assert command was NOT called
- `spy_get_calls <cmd>` - Get all invocations for custom assertions

**Example:**
```fish
#!/usr/bin/env fish

# Setup
spy_on git
spy_on npm

# Run code under test
my_function_that_calls_git_and_npm

# Verify
spy_assert_called git "commit -m"
spy_assert_called npm "install"
spy_assert_called_not npm "publish"

# Custom assertions
set -l calls (spy_get_calls git)
assert_string_contains "origin main" "$calls" "Git pushed to origin main"
```

**How it works:**
- Creates mock executable in `$TEST_CASE_TEMP_DIR/.spies/bin/<cmd>`
- Prepends spy directory to `$PATH` (isolated to test via begin/end blocks)
- Logs all invocations to `$TEST_CASE_TEMP_DIR/.spies/logs/<cmd>.log`
- Automatically cleaned up with temp directory

## Writing Tests

Create a test file in `test/cases/` (nested directories supported):

```fish
#!/usr/bin/env fish
# test/cases/my-feature/basic.fish

# Setup (use helpers if available)
mkdir -p "$TEST_CASE_TEMP_DIR/project"
cd "$TEST_CASE_TEMP_DIR/project"

# Run code under test
set -l OUTPUT (my_command arg1 arg2 2>&1)

# Assert results
assert_output_contains "expected string" "Command produced expected output"
assert_file_exists "$TEST_CASE_TEMP_DIR/project/output.txt"
assert_file_contains "$TEST_CASE_TEMP_DIR/project/output.txt" "data" "Output file contains data"
```

**Tips:**
- Tests auto-discovered by filename pattern `test/cases/**/*.fish`
- No need to register tests - just create the file
- Use `$TEST_CASE_TEMP_DIR` for temporary files (auto-cleaned)
- Spy on external commands to verify behavior without side effects
- Group related tests in subdirectories (e.g., `test/cases/my-feature/`)

**Complete example with spies:**

```fish
#!/usr/bin/env fish
# test/cases/deploy/production.fish

# Setup spy
spy_on kubectl
spy_on docker

# Run deployment
deploy_to_production "v1.0.0"

# Verify kubectl was called
spy_assert_called kubectl "apply -f"
spy_assert_called kubectl "rollout status"

# Verify docker tag happened
set -l calls (spy_get_calls docker)
assert_string_contains "tag.*v1.0.0" "$calls" "Docker tagged with version"
```
