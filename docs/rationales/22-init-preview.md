## What

Add a dedicated `flo init preview` command for `open` and `start` that returns the first-open workspace init contract without mutating the checkout, workspace, or local Flo state.

## Why

`flo explain` is broad. It answers the whole "what will Flo do?" question. Entry points such as Raycast, editor commands, or future config tooling also need a narrower answer: "what exactly is the first-open workspace init?" A dedicated preview surface keeps that contract explicit and reusable.

## How

The core now exposes typed init-preview results built on top of the same planning layer as `flo explain`. The preview reports the resolved project and checkout, the current workspace action, whether the init would apply right now, and the editor and Claude bootstrap commands that define first-open behavior.

## When

Use this before refining workspace profiles, while designing project-specific init behavior, or from launcher integrations that want to preview the first-open layout before the user commits to the action.

## Where

The preview logic lives in the Flo core and is exposed through `flo init preview open` and `flo init preview start`. The README now documents the command as part of the public model.
