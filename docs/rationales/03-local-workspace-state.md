## What

Persist lightweight Flo workspace activity in XDG state so the tool can remember which checkouts were opened most recently and by which action.

## Why

Without local state, Flo has no memory beyond the live filesystem and live `cmux` workspaces. That makes higher-level UX like recents, "open last", and better launcher ordering impossible. A small local state file creates leverage without turning Flo into a database.

## How

Flo now writes a versioned JSON state file under XDG state. Each open or start action upserts a workspace record keyed by Flo workspace identity and records the last-opened timestamp plus the action that touched it.

## When

This state updates every time Flo successfully opens or starts work. It is intentionally passive; the user does not have to opt into a separate "recent projects" feature before the memory exists.

## Where

The state lives outside the repo so it can track long-lived work across multiple projects and entrypoints, while remaining easy to inspect or delete as a single file.
