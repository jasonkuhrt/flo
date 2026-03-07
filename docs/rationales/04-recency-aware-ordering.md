## What

Sort `flo list` and the interactive launcher using a simple relevance rule: open work first, then most recently touched work, then stable lexical ties.

## Why

The launcher should feel like an extension of active work, not a raw dump of discovered repos and checkouts. Once Flo has local activity state, the highest-value next step is to make that memory visible in ordering before adding more commands.

## How

Flo now enriches list output with persisted timestamps and sorts checkouts within each project by workspace-open status and recency. Projects themselves are sorted by whether they currently have open work and by the newest checkout they contain.

## When

This applies automatically anywhere `flo list` or the no-arg launcher is used. No configuration is required and no hidden heuristics beyond the documented ordering rule are introduced.

## Where

The ordering lives in the Flo core so CLI, Raycast, and any future launcher surface inherit the same relevance behavior from one place.
