# Development

## Installation for Development

Install via Fisher from your local clone to test the same path as users:

```bash
make install    # Uses Fisher to install from PWD
make uninstall  # Remove via Fisher
```

This ensures you're testing the exact same installation method as end users.

## Documentation

The README reference section is generated from `.md` files in `functions/`. After updating these files, regenerate the README:

```bash
make docs
```

Or directly:

```fish
./scripts/generate-readme-reference.fish
```

## Running Tests

```bash
make test                          # Run all tests
make test ARGS="--update"          # Update snapshots
make test ARGS="--file pattern"    # Run specific tests matching pattern
```

Examples:
```bash
make test ARGS="--file gitignore"  # Run only gitignore tests
make test ARGS="--file 'flo end'"  # Run all flo end tests
```

## Adding Tests

Add `.sh` files to `test/cases/` - they're auto-discovered. Tests have access to:
- Assertions: `pass`, `fail`, `assert_*`, `assert_snapshot`
- Helpers: `setup_temp_repo()`, `flo()`, etc. (see `test/helpers.sh`)
- Variables: `$TEMP_REPO`, `$TEST_DIR`, `$PROJECT_ROOT`

Framework docs: [`lib/test/README.md`](lib/test/README.md)

## Structure

- `functions/` - All Fish code (commands, CLI framework, lib files)
  - `flo.fish`, `end.fish`, etc. - Public commands
  - `__flo_lib_*.fish` - Internal library files (logging, internals, CLI framework)
- `lib/test/` - Generic test framework
- `test/cases/` - Test files
- `test/helpers.sh` - Flo-specific helpers
- `test/hooks.sh` - Test lifecycle

**Note**: Following Fisher conventions, all code lives in `functions/` with `__flo_lib_` prefix for internal libraries. Fisher only copies files from `functions/`, `completions/`, and `conf.d/` directories.
