# Flo

Start work, continue work, and finish work without rebuilding your environment by hand.

Flo resolves a task or branch, finds the owning project, creates or reuses the right checkout, restores the right workspace state, and opens the project with context ready for you and your tools.

By default, that means:

- `cmux` manages workspaces
- `zmx` restores persisted workspace state
- `nvim` is the default editor inside a checkout workspace

Raycast and the Claude skill are optional ways to invoke Flo.
They are not separate workflow engines.
This README describes the current Flo contract.

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
- Linear issues later
- Beads later

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

# Open the main workspace for a project
flo open dotfiles

# Reopen the most recent actionable workspace
flo open --last

# Start work from the current project's default source
flo start 123

# Start work from anywhere with an explicit project
flo start 123 --project dotfiles

# Start work from an explicit source
flo start gh:123

# Start work from a branch name
flo start feat/cmux-launcher

# Open an existing checkout directly
flo open heartbeat@feat-auth

# List active checkouts and workspaces
flo list

# Narrow list output to one project
flo list --project flo

# Show only currently open work
flo list --open

# Show the recent active work that still exists locally
flo recent

# Limit recents to one project and a short list
flo recent --project flo --limit 3

# Print the current checkout context for Claude or other tooling
flo context --json

# Export the current context as shell env vars
flo context --env

# Show current project, checkout, and workspace state
flo status

# Diagnose config, project discovery, and runtime binaries
flo doctor

# Bootstrap a starter config from the current repo
flo config init

# End a piece of work
flo end 123

# End work and jump back to main
flo end 123 --open-main
```

## What Happens When Flo Opens Main Project Work

When you run `flo open [project]`, Flo:

1. resolves the project, using the current directory first when possible
2. resolves that project's main checkout
3. focuses or creates the main `cmux` workspace for that checkout
4. restores workspace state through `zmx` if a saved workspace already exists
5. otherwise runs the project's first-open init flow
6. lands you in the expected editor/runtime state

This is the home-base path.
It is intentionally different from starting scoped feature work.

## What Happens When Flo Starts Scoped Work

When you run `flo start <selector>`, Flo:

1. resolves the selector using the current project context or an explicit `--project`
2. resolves the owning project
3. creates or reuses the correct checkout
4. prepares work context for humans and agents
5. opens or focuses the right `cmux` workspace
6. lands you in the project with the expected editor/runtime state

That is the scoped-work path.
It should usually land in a feature checkout rather than the main checkout.

Together, `flo open` and `flo start` define the main product shape:

- `flo open` gets you to the project's home base
- `flo start` gets you to a scoped checkout for active work

That split is the product.
Specific sources and entrypoints plug into it.

## Smart Routing

Flo should feel smart by default.
Explicit source prefixes should exist, but they should be the exception rather than the main thing users think about.

The intended routing model is:

- if you are already inside a configured project, Flo uses that project as the first routing hint
- a numeric selector like `123` routes to that project's default issue source
- an explicit source selector like `gh:123` always wins
- a general string that does not look like a source item can be treated as a branch name or fuzzy project/checkout target

Examples:

```bash
# Inside a project with GitHub as the default source
flo start 123

# Force a specific source
flo start gh:123

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

### Workspace Identity

Workspace titles are defaults for presentation.
They are not the durable identity of a Flo workspace.

The workspace identity algorithm should be:

1. canonicalize the checkout path with `realpath`
2. compute `flo.identity = sha256(canonicalCheckoutPath).slice(0, 12)`
3. stamp the workspace with Flo metadata

Required Flo metadata:

- `flo.identity`
- `flo.project`
- `flo.kind`

Suggested values:

- `flo.identity = 4f99918c0504`
- `flo.project = flo`
- `flo.kind = main | feature`

Lookup should work like this:

1. resolve the target checkout
2. canonicalize its path
3. compute `flo.identity`
4. scan `cmux` workspaces
5. inspect Flo metadata for each workspace via `sidebar-state`
6. match by `flo.identity` first, then the workspace `cwd` as a fallback

This means:

- the default title can be `flo:<project>` for main workspaces
- the default title can be `flo:<project>@<branch>` for feature workspaces
- users may rename workspace titles without breaking Flo's ability to find them later

### Init vs Restore

Flo should be strict about the difference between first open and return:

- on restore, `zmx` owns the workspace state
- on first open, Flo owns the init flow

Flo should not fight restored state.
If `zmx` can restore a workspace, Flo should restore it and stop being clever.
If there is no saved workspace yet, Flo should initialize one intentionally.

## nvim Integration

`nvim` should be tightly woven into Flo's default flow.

That does not mean editor support has to be hardcoded forever.
It means the first-class experience is intentionally:

- resolve work
- open or restore the correct workspace
- land in the default `nvim + claude` workspace inside the correct checkout

Editor integration can remain modular in architecture while still making `nvim` the default, built-in editor experience.

### nvim Init Profiles

The first-open workspace layout is a two-pane terminal layout:

- left pane: `nvim`
- right pane: `claude`
- restore behavior after first open belongs to `zmx`, not to Flo

The first-open `nvim` experience is project-aware.

Main checkout init can bias toward orientation:

- open `nvim`
- open a project view
- show `snacks.explorer` or a Flo-specific dashboard

Feature checkout init can bias toward execution:

- open `nvim`
- bias toward the active work context
- preload work-item context when available
- optionally open a narrower project view than the main checkout

The important boundary is:

- Flo owns init behavior
- `zmx` owns restore behavior

That keeps the first-open experience intentional without clobbering a restored workspace.

## Work Sources

Flo supports multiple work sources through one core interface.

Current source support:

- GitHub issues

Planned next sources:

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
- start work with an explicit project
- resume recent work

It should not become a separate workflow engine.

The current adapter lives in `integrations/raycast` and delegates to the Flo CLI:

- `Open Flo Workspace` consumes `flo list --json` and calls `flo open`
- `Start Flo Work` consumes the project list and calls `flo start --project ...`

Repeatable Raycast workflows are exposed through the root `justfile`:

- `just raycast-dev`
- `just raycast-fix`
- `just raycast-check`
- `just raycast-build`
- `just raycast-lint`

### Claude Skill

The Claude skill should consume Flo state and Flo context.

The intended relationship is:

- Flo owns source resolution, checkout orchestration, and context generation
- the Claude skill consumes that state and context
- backend logic lives in Flo, not inside the skill

The current Claude-facing Flo surfaces are:

- `flo context --json`
  Return the current project, checkout, workspace metadata, and GitHub issue context when the branch is issue-backed.
- `flo ui sync`
  Update ambient `cmux` status for the current workspace.
- `flo ui log`
  Write milestone-grade log entries into the current workspace.
- `flo ui notify`
  Send attention-worthy `cmux` notifications for the current workspace.
- `flo ui claude-hook <hook>`
  Parse Claude hook JSON from stdin and map it into the Flo UI contract.
- `flo claude install-hooks`
  Install Flo's Claude hook bridge into `.claude/settings.local.json` for the current checkout.

A ready-to-call wrapper for hook commands lives at `integrations/claude/hooks/flo-ui-hook.sh`.

### Claude Hooks and Workspace Signals

Claude integration should be event-driven, but the event boundary belongs to Flo rather than `cmux`.

The skill and Claude hooks should call a small Flo UI layer such as:

- `flo ui sync`
- `flo ui notify`
- `flo ui log`

That layer owns the mapping into `cmux` status, log, and notification APIs.
Claude hooks should not call `cmux` directly.

The initial Claude-to-Flo signal contract should use only real Claude Code hooks:

- `Notification(permission_prompt)` routes to a Flo attention notification
- `Notification(idle_prompt)` routes to a Flo attention notification
- `Notification(elicitation_dialog)` routes to a Flo attention notification
- `PreCompact(auto)` routes to a Flo notification plus a Flo log entry
- `PreCompact(manual)` routes to a Flo log entry only
- `SessionStart(startup|resume|compact)` routes to Flo status synchronization
- `SubagentStart` and `SubagentStop` route to Flo status and short log updates

The initial policy should be strict:

- notifications are for attention-worthy events only
- status is for ambient state such as compaction or active subagent count
- logs are for milestone-grade events only
- compaction is visible, but only automatic compaction should interrupt

Flo should also avoid pretending Claude exposes hooks it does not.
In particular:

- `Stop` should not drive default notifications because it is too noisy in an interactive session
- `WorktreeCreate` and `WorktreeRemove` should not be used as passive observability hooks because they replace Claude's default worktree lifecycle
- `TaskCompleted` and `TeammateIdle` are better treated as future integrations once Flo deliberately supports Claude team workflows
- the `cmux` progress bar should stay unused until Flo has a first-class task model with real completion semantics

## Command Model

The initial public command model is:

- `flo`
  Open the interactive launcher.
- `flo start <selector> [--project <project>]`
  Resolve work, create or reuse a checkout, prepare context, and open it. `--project` is the global-launcher path.
- `flo open [selector]`
  Open or focus a project's main checkout workspace, or an existing checkout when a more specific selector is given. `flo open --last` reopens the most recent actionable workspace directly.
- `flo context`
  Print the current project and checkout context, primarily for Claude and other automation. `flo context --env` emits a shell-safe export block.
- `flo status`
  Show the current project, checkout, expected workspace, and whether that workspace is already open.
- `flo list`
  List active checkouts and workspace state. `--project` narrows the result to one resolved project and `--open` keeps only currently open workspaces.
- `flo recent`
  Show the recent work Flo still considers actionable, ordered by recency. `--project` narrows the source set and `--limit` trims the result.
- `flo doctor`
  Diagnose config resolution, project context, and required runtime binaries from the current working directory.
- `flo config init`
  Scaffold a validated starter config at the resolved Flo config path.
- `flo end [selector]`
  Resolve or conclude a piece of work and clean up the checkout when appropriate. `--open-main` returns to the main workspace immediately after cleanup.
- `flo prune`
  Clean up stale local workspace, worktree, and recent-state records.
- `flo ui ...`
  Bridge Claude and other automation into Flo-owned `cmux` status, log, and notification behavior.

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

1. use the current directory to narrow project resolution when possible, or accept `--project` when launched globally
2. resolve the selector with smart routing rules
3. create or reuse the correct checkout
4. generate normalized work context
5. create or focus the right `cmux` workspace
6. land in the expected editor/runtime state

Example:

```bash
flo start 123 --project dotfiles
```

### Open Main Project

```bash
flo open dotfiles
```

Expected behavior:

- resolve a project target
- resolve that project's main checkout
- focus the existing main `cmux` workspace when one exists
- otherwise create the main workspace and run the init flow

### Open Existing Checkout

```bash
flo open heartbeat@feat-auth
```

Expected behavior:

- resolve a more specific checkout target
- focus the existing checkout workspace when one exists
- otherwise create/open that checkout workspace

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

The config format is JSON and validated at load time.
The model will continue to grow, but malformed fields should fail fast with precise config-path errors instead of surfacing later during runtime.
Runtime config can define global `main` and `feature` workspace profiles.
These profiles override bootstrap commands and split direction for the corresponding workspace kind.

The current config file is JSON at `~/.config/flo/config.json`.

Minimal example:

```json
{
  "discovery": {
    "roots": ["~/projects/jasonkuhrt"]
  },
  "runtime": {
    "profiles": {
      "feature": {
        "splitDirection": "bottom",
        "editorCommand": "nvim +FloFeatureInit"
      }
    }
  },
  "projects": [
    {
      "name": "dotfiles",
      "path": "~/projects/jasonkuhrt/dotfiles",
      "defaultSource": "github",
      "github": {
        "repo": "jasonkuhrt/dotfiles"
      },
      "workspaceProfiles": {
        "main": {
          "editorCommand": "nvim +FloMainInit"
        }
      }
    }
  ]
}
```

## Non-Goals

- shell-specific implementation as part of the product contract
- GitHub-specific behavior baked into Flo core
- `cmux` becoming the source of truth for work state
- a second workflow engine inside the Claude skill
- forcing Raycast as the primary interface

## Current Scope

Implemented now:

- typed Flo core
- GitHub-backed issue and branch routing
- main-checkout `flo open` and scoped `flo start`
- checkout/worktree orchestration
- rename-safe `cmux` workspace lookup via Flo metadata
- `cmux` plus `zmx` runtime integration
- first-open `nvim + claude` workspace init
- `flo end` and `flo prune`
- `flo context` for Claude-facing checkout context
- `flo ui` for Claude hook -> Flo -> `cmux` integration
- local workspace activity state for recency-aware flows
- recency-aware ordering in `flo` launcher and `flo list`
- experimental Raycast adapter over the Flo CLI

Deferred for later:

- Linear source execution
- Beads source execution
