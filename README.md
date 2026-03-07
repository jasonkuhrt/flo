# Flo

Start work, continue work, and finish work without rebuilding your environment by hand.

Flo resolves a task or branch, finds the owning project, creates or reuses the right checkout, restores the right workspace state, and opens the project with context ready for you and your tools.

By default, that means:

- `cmux` manages workspaces
- `zmx` restores persisted workspace state
- `nvim` is the default editor inside a checkout workspace

Raycast and the Claude skill are optional ways to invoke Flo.
They are not separate workflow engines.

This README currently doubles as the product spec for the initial release.
Only the final section, "Temporary Implementation Notes", is intentionally non-final.

## Why Flo Exists

Starting real work usually means doing the same setup every time:

- figure out which project the work belongs to
- resolve the work item from the right system
- create or find the right branch or worktree
- move into the correct checkout
- open the right workspace
- make the work context visible to Claude or other agents

Flo turns that from a pile of shell habits into one coherent system.

## The Flo Model

Flo is easiest to understand in this order:

### 1. Work Source

A work source is where work comes from.

Examples:

- GitHub issues
- Linear issues
- Beads

Flo does not assume one source forever.
A source resolves a selector, returns metadata, and provides context for the work.

### 2. Project

A project is a long-lived codebase.

Examples:

- `dotfiles`
- `heartbeat`
- `graphql-kit`

Projects define defaults such as:

- which work source to use by default
- how to bootstrap a new checkout
- how Flo should open that project

### 3. Checkout

A checkout is the concrete directory where work actually happens.

Examples:

- the main checkout for a project
- a feature branch worktree
- a spike worktree

Flo opens checkouts, not abstract repos.

### 4. Workspace

A workspace is the running terminal environment attached to a checkout.

In Flo, `cmux` is the workspace runtime.
`zmx` persists and restores workspace state.

### 5. Editor

`nvim` is the default editor inside a checkout workspace.

Editor integration should stay modular, but `nvim` is intentionally first-class in Flo.
It is part of the normal working environment, not an afterthought.

### 6. Entrypoint

An entrypoint is how you ask Flo to do work.

Examples:

- the CLI
- Raycast
- a Claude skill
- an editor command later

Entrypoints call Flo core.
They do not redefine Flo behavior.

## Core Ideas

- Flo is project-oriented. Work should resolve into a real project and a real checkout quickly.
- Checkouts are first-class. A repo and a checkout are not the same thing.
- Worktrees are normal. Flo expects multiple active checkouts per project.
- `cmux` is the runtime. Raycast and the Claude skill are entrypoints into that runtime.
- `nvim` is the default editor experience inside a workspace.
- Work context is generated from the source item and checkout instead of being repeated by hand.

## Quick Examples

```bash
# Open the interactive launcher
flo

# Start work from the current project's default source
flo start 123

# Start work from an explicit source
flo start gh:123
flo start linear:ENG-241
flo start bead:parser/cleanup-import-resolution

# Start work from a branch name
flo start feat/cmux-launcher

# Open an existing project or checkout
flo open dotfiles
flo open heartbeat@feat-auth

# List active checkouts and workspaces
flo list

# End a piece of work
flo end 123
```

## What Happens When Flo Starts Work

When you run `flo start <selector>`, Flo:

1. resolves the selector using the current project context and source rules
2. resolves the owning project
3. creates or reuses the correct checkout
4. prepares work context for humans and agents
5. opens or focuses the right `cmux` workspace
6. lands you in the project with the expected editor/runtime state

That sequence is the product.
Specific sources and entrypoints plug into it.

## Smart Routing

Flo should feel smart by default.
Explicit source prefixes should exist, but they should be the exception rather than the main thing users think about.

The intended routing model is:

- if you are already inside a configured project, Flo uses that project as the first routing hint
- a numeric selector like `123` routes to that project's default issue source
- a selector that matches a Linear-style pattern routes to Linear
- an explicit source selector like `gh:123` or `bead:core/parser-cleanup` always wins
- a general string that does not look like a source item can be treated as a branch name or fuzzy project/checkout target

Examples:

```bash
# Inside a project with GitHub as the default source
flo start 123

# Inside a project with Linear as the default source
flo start ENG-241

# Force a specific source
flo start gh:123
flo start linear:ENG-241

# Branch-oriented work
flo start feat/cmx-launcher
```

## cmux Integration

`cmux` is not just a place Flo opens terminals.
It is the runtime Flo manages.

The intended behavior is:

- every configured project has a main workspace bound to its main checkout
- every active feature checkout has its own sibling workspace
- Flo uses `zmx` to persist and restore workspace state for both main and feature workspaces
- workspace identity is tied to checkout identity, not just repo name or branch name
- if a workspace already exists, Flo focuses and restores it
- if a workspace does not exist, Flo creates it and applies the project's expected startup behavior

In practice, starting feature work usually means two important workspaces exist:

- the main workspace for the project's main checkout
- the feature workspace for the active feature checkout

The main workspace is the stable home base for the project.
The feature workspace is the dedicated execution context for the work you are doing now.

Flo should keep both easy to reach and safe to restore.

## nvim Integration

`nvim` should be tightly woven into Flo's default flow.

That does not mean editor support has to be hardcoded forever.
It means the first-class experience is intentionally:

- resolve work
- open or restore the correct workspace
- land in `nvim` inside the correct checkout

Editor integration can remain modular in architecture while still making `nvim` the default, built-in editor experience.

## Work Sources

Flo supports multiple work sources through one core interface.

Initial source set:

- GitHub issues
- Linear issues
- Beads

A work source is responsible for:

- resolving selectors into canonical work items
- fetching metadata about the work
- providing a branch or checkout hint
- producing normalized context for the checkout
- optionally performing source-specific actions such as assignment, claiming, or completion

Flo core is intentionally source-agnostic.
No source-specific assumptions should leak into checkout orchestration or workspace behavior.

## Checkouts and Worktrees

Worktrees are first-class in Flo.

The core model is:

- a project owns many checkouts
- a piece of work usually maps to one checkout
- a workspace runs against one checkout

This means:

- multiple active worktrees in one project are expected
- checkout identity is path-based, not branch-name-only
- workspace identity in `cmux` follows the checkout

If a matching checkout already exists, Flo reuses it.
If not, Flo creates the right checkout for the requested work.

## Entrypoints

### CLI

The CLI is the canonical interface.

Every other entrypoint should delegate to it or to the same Flo core APIs.

### Raycast

Raycast is an experimental global entrypoint.

Its job is to let you invoke Flo from anywhere on macOS:

- find a project
- find a checkout
- start work
- resume recent work

It should not become a separate workflow engine.

### Claude Skill

The Claude skill should consume Flo state and Flo context.

The intended relationship is:

- Flo owns source resolution, checkout orchestration, and context generation
- the Claude skill consumes that state and context
- backend logic lives in Flo, not inside the skill

## Command Model

The initial public command model is:

- `flo`
  Open the interactive launcher.
- `flo start <selector>`
  Resolve work, create or reuse a checkout, prepare context, and open it.
- `flo open [selector]`
  Open or focus an existing project or checkout.
- `flo list`
  List active checkouts and workspace state.
- `flo end [selector]`
  Resolve or conclude a piece of work and clean up the checkout when appropriate.
- `flo prune`
  Clean up stale local state.

## Project Discovery and Defaults

Flo discovers projects from configured roots.

Discovery should support:

- fuzzy resolution by project name
- explicit paths
- per-project defaults
- source routing

Useful project defaults include:

- default work source
- bootstrap command for new checkouts
- workspace behavior
- preferred editor
- project-specific context files

## End-to-End Flows

### Start Work

```bash
flo start 123
```

Expected behavior:

1. use the current directory to narrow project resolution when possible
2. resolve the selector with smart routing rules
3. create or reuse the correct checkout
4. generate normalized work context
5. create or focus the right `cmux` workspace
6. land in the expected editor/runtime state

### Open Existing Work

```bash
flo open dotfiles
flo open heartbeat@feat-auth
```

Expected behavior:

- resolve a project or checkout target
- present an interactive picker if needed
- focus the existing `cmux` workspace when one exists
- otherwise create/open the target workspace

### End Work

```bash
flo end 123
```

Expected behavior:

- resolve the active work item and checkout
- perform source-specific completion or closure when requested
- clean up or keep the checkout based on explicit policy
- update local Flo state

The cleanup policy is source-aware, but Flo should remain explicit and safe.

## Configuration

Flo has two configuration scopes:

- global configuration
  Defines project roots, default runtime behavior, and source credentials or endpoints.
- project configuration
  Defines project-level defaults such as source routing, bootstrap commands, editor/runtime behavior, and context imports.

The config format is intentionally not finalized in this spec.
What is fixed is the configuration model.

## Non-Goals

- shell-specific implementation as part of the product contract
- GitHub-specific behavior baked into Flo core
- `cmux` becoming the source of truth for work state
- a second workflow engine inside the Claude skill
- forcing Raycast as the primary interface

## Temporary Implementation Notes

This section is temporary and exists only to align on the initial build plan.

### Clean-Slate Direction

- archive the existing `jasonkuhrt/flo` repo as `flo-legacy`
- create a new `flo` project from the template repo
- port concepts and test intent from legacy Flo, not the Fish implementation

### Legacy Concepts Worth Preserving

- project-root discovery and fuzzy project resolution
- issue-or-branch style selection, generalized into source selectors
- worktree-first workflow
- active checkout listing and pruning
- generated Claude context for a checkout

### Initial Delivery Slice

The first meaningful slice should prove the new architecture, not just recreate the old CLI.

Initial slice:

- typed Flo core
- GitHub source
- checkout and worktree orchestration
- `cmux` plus `zmx` integration
- canonical CLI commands: `flo`, `flo start`, `flo open`, `flo list`

### Follow-On Slices

- Claude skill integration on top of Flo state and context
- experimental Raycast extension as an entrypoint over Flo core
- Linear source
- Beads source
- end-of-work lifecycle and cleanup policy
