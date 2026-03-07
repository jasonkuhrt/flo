## What

Add strict runtime validation for Flo config so malformed fields fail immediately with targeted path-based error messages.

## Why

Unchecked JSON pushes failure downstream into unrelated commands. That is bad DX because the user sees a launcher or workspace error when the real problem is simply that a config field has the wrong shape. Validation lowers cognitive load by making the failure local and obvious.

## How

Flo now parses config through explicit field validators instead of casting raw JSON. The validators enforce object shapes, non-empty strings, valid source kinds, and string arrays for discovery roots and aliases.

## When

Validation runs every time Flo loads config, before discovery, workspace planning, or launch behavior begins.

## Where

The validation lives inside the config loader so every entrypoint, including CLI and Raycast, benefits from the same failure mode without extra guard code.
