## What

Add `flo list --open` so the list command can answer "what is currently alive?" directly.

## Why

An inventory of all checkouts is useful, but a lot of day-to-day navigation starts from the narrower question of which workspaces are already open right now. That deserves a first-class filter instead of post-processing a larger result mentally or in shell pipelines.

## How

The core list query now accepts an `openOnly` mode that filters checkout entries to `workspaceOpen === true` and drops projects with no remaining matching checkouts.

## When

Use this when reorienting after a context switch, when deciding what to prune, or when checking which work is already live before opening something new.

## Where

Filtering happens in the shared state query so the same active-work view can be reused by Raycast and other launch surfaces later.
