## What

Add a first-class `flo explain` command for `open`, `start`, and `end` so Flo can show the resolved project, checkout, workspace action, and first-open init plan before making changes.

## Why

Flo is getting more opinionated. As it gains workspace profiles, source routing, and restore behavior, users need a deterministic way to ask "what would Flo do here?" without mutating the repo or the runtime. A typed explain surface lowers trust cost and makes global launchers safer.

## How

The core now builds explicit workspace plans and init plans from the same resolution logic used by the mutating commands. `flo explain` reuses that logic and reports whether Flo would focus an existing workspace, create a new one, or close one during `end`, along with the editor and Claude bootstrap commands for first-open init.

## When

Use this before running Flo from Raycast, before cleaning up a feature checkout, after changing config, or whenever the current cwd and selector routing are not obvious.

## Where

The planning logic lives in the Flo core so other entrypoints can reuse it later. The CLI exposes it as `flo explain open`, `flo explain start`, and `flo explain end`, and the README documents the new contract.
