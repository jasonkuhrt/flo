## What

Add an `Open Last Flo Workspace` Raycast command that directly runs `flo open --last`.

## Why

The fastest reentry path should be a first-class command, not a sequence of opening Raycast, selecting Flo, then selecting a recent item. This is the purest low-cognitive-load surface in the product because it collapses the common case to one action.

## How

The command is a no-view Raycast action that delegates entirely to the CLI's existing `open --last` behavior and reports success or failure through Raycast toasts.

## When

Use this when you simply want to get back to the most recent actionable workspace as fast as possible.

## Where

The command lives in the Raycast adapter and deliberately reuses the CLI path so there is still only one definition of "last workspace" in the system.
