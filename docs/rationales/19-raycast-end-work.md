## What

Add an `End Flo Work` Raycast command that lists feature checkouts and supports both plain end and "end and open main" actions.

## Why

Raycast should not only enter work; it should also close it cleanly. Ending feature work is a high-value action because it combines cleanup, workspace closure, and optional return to main in one deliberate operation.

## How

The command consumes `flo list --json`, filters out main checkouts, and maps each remaining item to `flo end <selector>` or `flo end <selector> --open-main`.

## When

Use this when finishing a branch from anywhere on the machine and wanting the same explicit cleanup behavior without dropping into a shell.

## Where

The command lives in Raycast but relies entirely on typed Flo surfaces, so its notion of what can be ended stays aligned with the CLI.
