## What

Add `flo home` as the explicit command for opening the canonical main workspace of the current or selected project.

## Why

`flo open` is flexible, but it is not semantically crisp. Flo now has a strong distinction between project home-base work and scoped checkout work. A dedicated `home` command makes that intent visible in CLI usage, launcher integrations, and later automation.

## How

`flo home` is implemented as a thin semantic wrapper over the existing main-workspace resolution path. It only accepts project selectors, rejects checkout selectors, and reuses the same workspace creation and restore logic as `flo open` for main checkouts.

## When

Use this when you want to return to the stable project home base without thinking about checkout selectors or whether `open` might target something more specific.

## Where

The command is exposed through the main CLI, re-exported from Flo core, tested at the integration level, and documented in the README command model.
