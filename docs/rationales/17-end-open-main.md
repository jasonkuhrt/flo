## What

Add `flo end --open-main`, which reopens the project's main workspace immediately after feature-work cleanup.

## Why

Ending scoped work is usually followed by the same next action: return to the project home base. Making that a first-class flag removes a repetitive manual step at the exact moment when the user is already done thinking about the feature checkout.

## How

After closing the feature workspace, killing managed `zmx` sessions, and removing the worktree, Flo optionally reuses normal open logic to focus or create the main workspace for the same project.

## When

Use this when finishing a branch and wanting to land back in the project's default workspace in one motion.

## Where

The behavior is implemented inside the core end-work flow so every entrypoint can expose the same "close feature, return home" action consistently.
