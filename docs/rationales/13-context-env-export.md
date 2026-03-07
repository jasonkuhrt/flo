## What

Add `flo context --env`, a shell-safe export format for the current Flo context.

## Why

JSON is the right interchange format for structured tools, but a lot of useful local automation still wants environment variables. A first-class env export removes glue code and keeps every consumer aligned to the same resolved project and checkout model.

## How

Flo now formats the existing typed context result into `export KEY='value'` lines for project, checkout, workspace, and issue metadata. The output is designed to be consumed directly by shells and simple scripts.

## When

Use this in shell functions, editor commands, Raycast helpers, or any local workflow that wants current Flo context without needing a JSON parser.

## Where

The formatter lives in the Flo core because context export is a domain concern, not a CLI-only presentation detail.
