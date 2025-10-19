# Flo

GitHub issues → Git worktrees → Claude context

Create worktrees from GitHub issues with automatic Claude setup.

**Without Flo:**

```fish
git worktree add ../proj_feat-123-title -b feat/123-title
cd ../proj_feat-123-title
cp -r ../proj/.serena/cache ./serena/cache  # Copy Serena cache (if present)
pnpm install
# Tell Claude about the issue manually upon your next session.
```

**With flo:**

```fish
flo 123
```

## Installation

### Fisher

```fish
fisher install jasonkuhrt/flo
```

<details>
<summary>Manual</summary>

```fish
git clone https://github.com/jasonkuhrt/flo.git ~/projects/flo
cd ~/projects/flo
make install
```

</details>

<details>
<summary>Requirements</summary>

- **Fish shell** (3.0+)
- **git** and **GitHub CLI** (`gh`) - must be authenticated (`gh auth login`)
- **jq** - JSON parser
  - macOS: `brew install jq`
- **pnpm** - for auto-installing dependencies (optional but recommended)

</details>

<!-- REFERENCE_START -->
## Reference

Run any command with \`--help\` for detailed help.

### `flo`

```

flo

Create worktree from branch or GitHub issue

COMMANDS
  flo        Create worktree from branch or GitHub issue
  list       List all git worktrees with branches and paths
  prune      Clean up Git metadata for manually deleted worktrees
  rm         Safely remove a git worktree by branch name or issue number

OPTIONS
  -h, --help       Show this help message
  -v, --version    Show version information

WORKTREE ORGANIZATION

  Flo creates worktrees as siblings to your main project:
    ~/projects/myproject/                      (main repo on main branch)
    ~/projects/myproject_feat-123-add-auth/    (worktree for feat/123-add-auth)
    ~/projects/myproject_fix-456-bug-fix/      (worktree for fix/456-bug-fix)

  Running flo multiple times for the same branch is safe - it updates Claude context without recreating the worktree.


ISSUE MODE

  When you run 'flo 123':
    1. Fetches issue #123 from GitHub
    2. Auto-assigns issue to you
    3. Creates branch with smart prefix:
         feat/123-<title> for features
         fix/123-<title> for bugs
         docs/123-<title> for documentation
         refactor/123-<title> for refactoring
         chore/123-<title> for chores
    4. Creates worktree: ../<project>_<branch>/
    5. Copies Serena MCP cache if present (speeds up symbol indexing)
    6. Sets up .claude/CLAUDE.md (one-time)
    7. Generates .claude/CLAUDE.local.md with issue context
    8. Runs pnpm install
    9. Ready to code!


CLAUDE INTEGRATION

  When you create a worktree from an issue, flo uses a two-file system:

  .claude/CLAUDE.md (one-time):
    - Instructs Claude to read .claude/CLAUDE.local.md
    - Prepended to existing CLAUDE.md if present
    - Committed to your repo

  .claude/CLAUDE.local.md (per-issue):
    - Overwritten each run with issue context
    - Gitignored - never committed
    - Worktree-specific


SERENA MCP INTEGRATION

  If you're using Serena MCP (github.com/oraios/serena) for semantic code analysis:
    - Flo automatically copies .serena/cache/ to new worktrees
    - Avoids re-indexing symbols (can save minutes on large projects)
    - Only happens when creating new worktrees (not when reusing)
    - Requires .serena/cache/ to exist in your main project
    - Pre-index once: uvx --from git+https://github.com/oraios/serena serena project index


EXAMPLES

  flo 123                    Create from GitHub issue
  flo feat/new-feature       Create from branch name
```

### `flo list`

```

flo list

List all git worktrees with branches and paths

Shows all worktrees with their paths, branches, and commits.
```

### `flo rm`

```

flo rm

Safely remove a git worktree by branch name or issue number

POSITIONAL PARAMETERS
  <branch-name-or-issue>    Branch name or issue number of the worktree to remove


ABOUT

  Safely removes a worktree by branch name or issue number.
  Calculates the path automatically and uses Git to properly
  delete it. Always prefer this over 'rm -rf' to keep Git
  state clean.

  When given an issue number, finds the worktree created with
  'flo <issue-number>' and removes it.


EXAMPLES

  flo rm 1320                  # Remove by issue number
  flo rm feat/123-add-auth     # Remove by branch name
  flo rm fix/memory-leak       # Remove by branch name
```

### `flo prune`

```

flo prune

Clean up Git metadata for manually deleted worktrees


ABOUT

  Use this if you deleted with `rm -rf` instead of `flo rm`.
```
<!-- REFERENCE_END -->
## Development

See [DEVELOPMENT.md](DEVELOPMENT.md) for development instructions.
