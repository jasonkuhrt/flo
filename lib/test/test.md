---
{
  "description": "Run test cases from the test/cases directory",
  "parametersPositional": [
    {
      "name": "pattern",
      "description": "Filter tests by name pattern (case-insensitive substring match)",
      "required": false
    }
  ],
  "parametersNamed": [
    {
      "name": "--update",
      "short": "-u",
      "description": "Update snapshots on mismatch",
      "hasValue": false
    },
    {
      "name": "--file",
      "short": "-f",
      "description": "Filter tests by name pattern (same as positional argument)",
      "hasValue": true
    },
    {
      "name": "--tags",
      "description": "Run tests with specified tags (space-separated, OR logic)",
      "hasValue": true,
      "multiple": true
    },
    {
      "name": "--all",
      "description": "Run all tests regardless of tags (default: only untagged tests)",
      "hasValue": false
    },
    {
      "name": "--help",
      "short": "-h",
      "description": "Show this help message",
      "hasValue": false
    }
  ],
  "examples": [
    {
      "command": "./test.sh",
      "description": "Run all untagged tests (fast tests only)"
    },
    {
      "command": "./test.sh --all",
      "description": "Run all tests including slow/tagged ones"
    },
    {
      "command": "./test.sh --tags gh slow",
      "description": "Run tests tagged with 'gh' OR 'slow'"
    },
    {
      "command": "./test.sh --tags untagged",
      "description": "Explicitly run only untagged tests"
    },
    {
      "command": "./test.sh 'branch mode'",
      "description": "Run tests matching 'branch mode' pattern"
    },
    {
      "command": "./test.sh -f 'end'",
      "description": "Run tests matching 'end' using --file flag"
    },
    {
      "command": "./test.sh --update",
      "description": "Run tests and update all snapshots"
    },
    {
      "command": "./test.sh --tags gh --update",
      "description": "Run GitHub tests and update their snapshots"
    }
  ],
  "exitCodes": {
    "0": "All tests passed",
    "1": "One or more tests failed"
  }
}
---

## ABOUT

Custom Fish shell test framework for flo. Automatically discovers and runs tests from `test/cases/` directory.

Tests are discovered recursively and run in isolated environments with automatic cleanup.

## Test Structure

Each test file in `test/cases/` is a standalone Fish script:

```fish
# test/cases/flo/branch-mode.fish
setup_temp_repo
flo feat/test-branch >/dev/null 2>&1
assert_dir_exists "$WORKTREE_PATH"
```

Test names are generated from file paths:
- `test/cases/flo-end/basic.fish` → `"Flo End > Basic"`
- `test/cases/flo/branch-mode.fish` → `"Flo > Branch Mode"`

## Test Tagging

Tests can declare tags for selective execution:

```fish
tags slow gh

setup_temp_repo
# ... test code
```

Tags must be the first non-blank, non-comment line in the file.

**Tag Behavior:**

- **Default (no flags)**: Runs only untagged tests (fast development workflow)
- **`--tags TAG...`**: Runs tests with ANY of the specified tags (OR logic)
- **`--tags untagged`**: Explicitly run only untagged tests (same as default)
- **`--all`**: Run all tests regardless of tags (useful for CI)

**Common Tags:**

- `slow` - Tests that take significant time (API calls, network operations)
- `gh` - Tests that interact with GitHub API
- `integration` - Integration tests requiring external services

## Snapshots

The framework supports snapshot testing for comparing output:

```fish
assert_snapshot "test-name" "$actual_output"
```

Use `--update` flag to update snapshots when intentionally changing behavior.

## Test Isolation

Each test runs in a clean environment:

- **Unique temp directory**: `$TEST_CASE_TEMP_DIR` created per test
- **Function scope isolation**: Fish `begin/end` blocks prevent leakage
- **Automatic cleanup**: Temp directories removed after each test
- **Hook support**: `before_each`, `after_each`, `before_all`, `after_all`

## Assertions

Available assertion functions (from `lib/test/assertions.fish`):

| Function | Parameters | Description |
|----------|------------|-------------|
| `pass` | `message` | Mark test as passed |
| `fail` | `message` | Mark test as failed |
| `assert_success` | `message` | Assert last command succeeded |
| `assert_string_contains` | `needle` `haystack` | Assert substring match |
| `assert_file_exists` | `path` | Assert file exists |
| `assert_dir_exists` | `path` | Assert directory exists |
| `assert_file_contains` | `path` `pattern` | Assert file contains pattern |
| `assert_snapshot` | `name` `content` | Compare against snapshot |

## Spies and Mocking

The framework includes a spy system for mocking commands:

```fish
spy_on gh

# Assertions
spy_assert_called gh
spy_assert_called gh "pr merge"
spy_get_calls gh
```

## Hooks

Define lifecycle hooks in `test/hooks.fish`:

```fish
function before_all
    # Run once before any tests
end

function before_each
    # Run before each test
end

function after_each
    # Run after each test
end

function after_all
    # Run once after all tests
end
```

## Filtering

Filter tests by name pattern (case-insensitive substring match):

```fish
./test.sh 'branch mode'     # Matches "Flo > Branch Mode"
./test.sh 'end'             # Matches all "Flo End > *" tests
./test.sh -f 'github'       # Same using --file flag
```

## Development Workflow

**Fast iteration** (skip slow tests):
```bash
./test.sh
```

**Full test suite** (CI):
```bash
./test.sh --all
```

**Test specific functionality**:
```bash
./test.sh 'end'            # Test flo end command
./test.sh --tags gh        # Test GitHub integration
```

**Update snapshots**:
```bash
./test.sh --update         # Update all snapshots
./test.sh 'help' --update  # Update specific test snapshots
```
