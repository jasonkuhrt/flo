# Flo Tests

This directory contains tests for flo using [fishtape](https://github.com/jorgebucaran/fishtape).

## Installation

```fish
fisher install jorgebucaran/fishtape
```

## Running Tests

Run all tests:
```fish
fishtape tests/*.fish
```

Run specific test file:
```fish
fishtape tests/test_helpers.fish
```

## Writing Tests

Tests use the `@test` function with this syntax:

```fish
@test "description" actual_value = expected_value
@test "status check" (some_command) $status -eq 0
```

Example test file structure:

```fish
#!/usr/bin/env fish

# Load flo functions
set -l flo_root (dirname (dirname (status -f)))
source $flo_root/functions/helpers.fish

# Write tests
@test "validates issue numbers" (__flo_validate_issue_number 123) $status -eq 0
@test "rejects invalid input" (__flo_validate_issue_number "abc") $status -eq 1
```

## Test Organization

- `test_helpers.fish` - Tests for core helper functions
- `test_parse_args.fish` - Tests for argument parsing helpers
- Add more test files as needed for different components

## CI Integration

Fishtape outputs TAP-compliant results, making it easy to integrate with CI systems.