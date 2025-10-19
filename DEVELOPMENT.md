# Development

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
