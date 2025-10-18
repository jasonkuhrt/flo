# Development

## Documentation

The README reference section is generated from `--help` output. After updating `.md` files in `functions/`, regenerate the README:

```fish
flo --help
flo list --help
flo rm --help
flo prune --help
```

Copy the output to README.md to keep docs in sync.

## Running Tests

```bash
make test              # Run all tests
make test --update     # Update snapshots
```

## Adding Tests

Add `.sh` files to `test/cases/` - they're auto-discovered. Tests have access to:
- Assertions: `pass`, `fail`, `assert_*`, `assert_snapshot`
- Helpers: `setup_temp_repo()`, `flo()`, etc. (see `test/helpers.sh`)
- Variables: `$TEMP_REPO`, `$TEST_DIR`, `$PROJECT_ROOT`

Framework docs: [`lib/test/README.md`](lib/test/README.md)

## Structure

- `functions/` - Fish CLI code
- `lib/cli/` - Generic CLI framework
- `lib/test/` - Generic test framework
- `test/cases/` - Test files
- `test/helpers.sh` - Flo-specific helpers
- `test/hooks.sh` - Test lifecycle
