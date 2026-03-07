## What

Add `flo open --last`, a direct path back into the most recent still-valid workspace.

## Why

Once Flo knows what was recently active, the lowest-friction action is not "show me a list" but "take me back to the thing I was just doing." This is a leverage feature because it removes one more decision from the common re-entry path.

## How

Flo resolves recents through the same filtered recent-work view used by `flo recent`, takes the top actionable item, and reuses normal workspace open logic so all existing `cmux` and `zmx` behavior stays intact.

## When

Use this when bouncing back into work after a context switch, opening a global launcher, or returning to a machine later in the day.

## Where

The feature is implemented as a core helper plus a CLI flag so other entrypoints can later adopt the same "resume my last real thing" behavior.
