## What

Add `flo list --project <selector>` so list output can be narrowed to one resolved project.

## Why

As soon as Flo spans more than a handful of repos, the mental work of visually filtering a global list starts to outweigh the value of the command. A project filter keeps `flo list` useful as both a broad overview and a precise inspection tool.

## How

The list command now resolves an optional project selector through the same project resolution logic used elsewhere and limits the state graph to that single project before building list output.

## When

Use this when you know which repo you care about and want checkout/workspace state without the noise of the rest of the machine.

## Where

Filtering happens in the core state query, not in CLI presentation, so other entrypoints can request scoped list data without paying for or reimplementing a global dump first.
