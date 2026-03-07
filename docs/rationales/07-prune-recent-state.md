## What

Teach `flo prune` to remove stale recent-work records alongside orphaned `cmux` workspaces and pruned git worktrees.

## Why

Once recent state exists, it needs lifecycle management. Filtering stale entries at read time is useful, but leaving dead records on disk forever means the state store gradually becomes misleading and harder to inspect.

## How

Prune now computes the active workspace identities and checkout paths from the live project graph, then removes persisted records that match neither an active identity nor an active checkout path. The command reports which recent records were removed.

## When

This runs whenever the user invokes `flo prune`. It is especially useful after deleting worktrees outside Flo or after cleaning up a large batch of feature work.

## Where

The stale-state cleanup lives in the shared state layer, so any future maintenance command can reuse the same definition of what counts as dead recent work.
