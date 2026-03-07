## What

Add `--project` and `--limit` support to `flo recent`.

## Why

Recents are most useful when they can answer both broad and narrow questions: "what were my last few things?" and "what did I touch recently in this repo?" Adding small composable filters keeps the command useful without inventing separate subcommands.

## How

The recent-work query now accepts an optional project selector, which scopes the underlying live checkout set first, and an optional positive limit, which trims the final recency-ordered list.

## When

Use this when you want a compact recent list in a launcher, a shell prompt, or a quick repo-specific reentry path.

## Where

The filtering lives in the core recent-work query so every consumer can reuse the same scoped and capped recency model.
