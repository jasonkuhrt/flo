## What

Add `flo recent`, a focused command that lists recent work Flo can still resolve to a live local checkout.

## Why

Recency-aware ordering improves the general launcher, but there is still value in a surface that says "show me only the few things I actually touched recently." This reduces choice overload without requiring the user to think in terms of project discovery or selector syntax first.

## How

Flo joins persisted workspace activity with the currently discovered checkout set and filters out stale entries whose worktrees no longer exist. The result stays ordered by recency and retains enough selector data to be launched directly later.

## When

Use this when you want to jump back into a recent project quickly, especially after context switching across several checkouts or machines.

## Where

The feature is implemented in the Flo core so other entrypoints can reuse the same "recent and still valid" view instead of reimplementing stale-entry filtering themselves.
