# Generic Test Framework

Reusable test utilities for bash test suites.

## Quick Start

```bash
lib/test/cli           # Run tests
lib/test/cli --update  # Update snapshots (on mismatch, overwrites)
```

**Makefile**: `test: @lib/test/cli`

**Auto-discovered files**:
- `test/helpers.sh` - Project helpers (`$TEST_DIR`, `$PROJECT_ROOT` available)
- `test/hooks.sh` - Lifecycle hooks (`before_all()`, `after_each()`, `after_all()`)
- `test/cases/*.sh` - Test files

## Assertions

**Results**: `pass(msg)`, `fail(msg)`
**Files**: `assert_dir_exists(path)`, `assert_dir_not_exists(path, msg)`, `assert_file_exists(path)`, `assert_file_not_exists(path, msg)`
**Content**: `assert_output_contains(output, pattern, msg)`, `assert_file_contains(file, pattern, msg)`
**Status**: `assert_success(msg)`
**Snapshots**: `assert_snapshot(name, content)` - Creates/compares snapshots in `__snapshots__/`

## Hooks

**Conventional** (auto-sourced from `test/hooks.sh`):
- `before_all()` - Runs once before all tests
- `after_each()` - Runs after each test
- `after_all()` - Runs once after all tests

**Imperative** (for dynamic behavior):
- `register_test_cleanup(fn)`
- `register_test_cleanup_all(fn)`

## Variables

- `$TEMP_REPO` - Temp directory per test
- `$TEST_DIR`, `$PROJECT_ROOT` - Auto-discovered paths
- `$PASSED`, `$FAILED` - Test counts
