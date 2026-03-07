## What

Add `flo config init`, a command that scaffolds a validated starter config from the current working context.

## Why

Typed config is valuable only if the first-run path is low-friction. Asking users to memorize the file path and hand-author the initial JSON keeps Flo feeling heavier than it needs to be.

## How

The command resolves the real Flo config path, discovers the current project if one is available, and writes a minimal JSON config containing a discovery root plus an inferred project entry. Existing configs are left untouched unless `--force` is passed.

## When

Use this on first setup, after moving machines, or when pointing Flo at a new config path through `FLO_CONFIG_PATH`.

## Where

The feature is implemented in the Flo core and exposed through a CLI subcommand so future entrypoints can reuse the same bootstrapping logic without duplicating path inference or project inference.
