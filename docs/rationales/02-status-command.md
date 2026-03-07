## What

Add `flo status`, a cwd-oriented command that reports the current project, checkout, expected Flo workspace identity, whether that workspace is open, and any GitHub issue context implied by the current branch.

## Why

`flo doctor` explains the environment. `flo status` explains the current work. That distinction matters because the most common question after opening a repo is not "is the tooling installed?" but "what does Flo think I am working on right now, and is the right workspace already alive?"

## How

The core now resolves current status without requiring a launching action. It reuses the same checkout and workspace targeting logic as `flo open` and `flo start`, then reports the matching `cmux` workspace if one exists.

## When

Run this from inside any checkout when you want to verify whether Flo sees the right branch, whether that branch maps to an issue, and whether the matching workspace is already open before taking action.

## Where

The status logic lives in the Flo core so CLI, Raycast, and editor integrations can all ask the same "current work" question without duplicating discovery rules.
