## What

Replace the single-purpose `splitDirection` profile knob with a typed workspace layout object that Flo validates, previews, and executes consistently.

## Why

Flo now has `explain` and `init preview`, which means the runtime shape needs a real config model rather than an incidental flag. A layout object makes the first-open workspace contract explicit and keeps config, preview, and execution aligned.

## How

Workspace profiles now carry `layout`, including split direction, whether a secondary Claude pane exists, and which pane should be focused after init. Flo merges runtime and project profile layouts, validates impossible combinations, and drives workspace init from that resolved layout instead of from hardcoded pane assumptions.

## When

This matters whenever a project wants a different first-open pane arrangement, when previewing init behavior, or when future entrypoints need to reason about the workspace contract without re-deriving it from ad hoc flags.

## Where

The type model lives in the core Flo types and config loader. The runtime open/start path executes the layout, the preview/explain surfaces report it, and the README config example now documents the layout-based profile shape.
