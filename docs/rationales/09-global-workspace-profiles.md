## What

Add global `main` and `feature` workspace profiles to runtime config so Flo can vary bootstrap commands and pane direction by workspace kind.

## Why

Main work and scoped feature work have different ideal entry states. Encoding that distinction as typed profiles keeps the init behavior intentional and configurable without turning workspace creation into a pile of special cases.

## How

Runtime config now accepts `profiles.main` and `profiles.feature`, each able to override the editor command, Claude command, and Claude pane split direction. Flo merges those overrides with runtime defaults when building launch targets.

## When

These overrides apply only on first-open bootstrap or when a workspace needs to be recreated. Existing `zmx`-restored sessions still win on restore.

## Where

The profile selection happens in target planning, which means CLI, Raycast, and future entrypoints all inherit the same main-vs-feature init behavior automatically.
