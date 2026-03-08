## What

Add support for project-local Flo config at `.flo/config.json`, merged on top of machine-global Flo config for project-scoped defaults.

## Why

Some Flo behavior belongs to the repo, not the machine. Workspace profiles, aliases, default source routing, and worktree conventions are part of project intent. Keeping those defaults in the repo lowers setup cost, makes automation more portable, and reduces hidden machine-only behavior.

## How

Project discovery now looks for `.flo/config.json` in each repository root and merges that config over any matching global project entry. Local config can override project name, aliases, source defaults, GitHub repo mapping, worktree root, and workspace profiles, including the typed layout object.

## When

Use this when a repo wants its own Flo behavior without requiring every machine to duplicate the same project stanza in the global config.

## Where

The loader lives in the config layer, project discovery applies the merge during inference, and the README configuration section now documents `.flo/config.json` as the repo-owned config scope.
