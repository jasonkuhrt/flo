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

### Fisher (Recommended)

```fish
fisher install jasonkuhrt/flo
```

<details>
<summary>Local Development</summary>

For development, install from your local clone:

```fish
git clone https://github.com/jasonkuhrt/flo.git ~/projects/flo
cd ~/projects/flo
make install  # Uses Fisher to install from PWD
```

This ensures you test the same installation path as users.

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

Create worktree from branch or GitHub issue (shorthand for 'flo start')

COMMANDS
  end        End your work by removing a worktree
             (alias: rm)
  list       List all git worktrees with branches and paths
  prune      Clean up Git metadata for manually deleted worktrees
  rm         Safely remove a git worktree by branch name or issue number
  start      Start work by creating a worktree from an issue or branch

OPTIONS
  -h, --help       Show this help message
  -v, --version    Show version information

POSITIONAL PARAMETERS
  <issue-or-branch>    GitHub issue number or branch name (optional - shows interactive picker if omitted)

WORKTREE ORGANIZATION

  Flo creates worktrees as siblings to your main project:
    ~/projects/myproject/                      (main repo on main branch)
    ~/projects/myproject_feat-123-add-auth/    (worktree for feat/123-add-auth)
    ~/projects/myproject_fix-456-bug-fix/      (worktree for fix/456-bug-fix)

  Running flo multiple times for the same branch is safe - it updates Claude context without recreating the worktree.


INTERACTIVE SELECTION

  When you run 'flo' with no arguments:
    1. Fetches up to 100 open issues from GitHub
    2. Shows interactive picker:
         - Uses 'gum filter' (fuzzy search) for >10 issues
         - Uses 'gum choose' (simple list) for ≤10 issues
    3. Creates worktree for selected issue

  Requirements:
    - gum: https://github.com/charmbracelet/gum (install with: brew install gum)
    - gh CLI: https://cli.github.com (install with: brew install gh)

  Fallback: If gum or gh are not installed, shows help message instead.


BRANCH MODE

  When you run 'flo <branch-name>':
    1. Creates worktree with the exact branch name you provide
    2. No GitHub integration (no issue fetching, no auto-assign)
    3. No Claude context files generated
    4. Perfect for: experiments, quick fixes, non-issue work

  Examples:
    flo feat/experiment        # Creates feat/experiment branch
    flo fix/quick-bug          # Creates fix/quick-bug branch
    flo spike/new-tech         # Creates spike/new-tech branch


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
```

### `flo list`

```

flo list

List all git worktrees with branches and paths

FLAGS
  --project    Project to list worktrees for (name or path). Names resolved via ~/.config/flo/settings.json

Shows all worktrees with their paths, branches, and commits.
EXAMPLES
  flo list    # Show all worktrees for current project
  flo list --project backend    # List worktrees for different project (by name)
  flo list --project ~/projects/api    # List worktrees for project by path

SEE ALSO
  flo end
  flo prune

EXIT CODES
  0    Success

```

### `flo rm`

```

flo end

End your work by removing a worktree

POSITIONAL PARAMETERS
  <branch-name-or-issue>    Branch name, issue number, or worktree directory name to remove (optional - defaults to current worktree)

FLAGS
  --force, -f    Force removal even with uncommitted changes, and force-delete branch (git branch -D)
  --keep-branch, -k    Keep the branch after removing the worktree (by default, branch is deleted)
  --yes, -y    Skip confirmation prompt (non-interactive mode)
  --project    Project to operate on (name or path). Names resolved via ~/.config/flo/settings.json


ABOUT

  Safely removes a worktree by branch name, issue number, or worktree directory name.
  Calculates the path automatically and uses Git to properly delete it.
  **By default, also deletes the associated git branch** to prevent orphaned branches from accumulating.

  Always prefer this over 'rm -rf' to keep Git state clean.

  When called without arguments, interactively removes the current worktree (if pwd is a worktree).

  When given an issue number, finds the worktree created with 'flo <issue-number>' and removes it.

  ## Branch Deletion

  - **Default behavior**: Deletes the branch after removing the worktree (using `git branch -d`)
  - **--keep-branch**: Preserves the branch after removal
  - **--force**: Force-deletes branches with unmerged changes (using `git branch -D`)
EXAMPLES
  flo rm    # Remove current worktree (interactive)
  flo rm 1320    # Remove by issue number
  flo rm #1320    # Remove by issue number (# is optional)
  flo rm feat/123-add-auth    # Remove by branch name
  flo rm fix/memory-leak    # Remove by branch name
  flo rm myproject_feat-123-add-auth    # Remove by worktree directory name
  flo rm --yes    # Remove current worktree without confirmation
  flo rm -y    # Short form of --yes
  flo rm --force    # Force remove current worktree
  flo rm --force --yes    # Force remove without confirmation (for automation)
  flo rm 1320 --force    # Force removal with uncommitted changes and force-delete branch
  flo rm --keep-branch    # Remove worktree but keep the branch
  flo rm feat/test --keep-branch    # Remove specific worktree but preserve the branch
  flo end --project backend    # Remove current worktree from different project
  flo end 123 --project ~/projects/api    # Remove worktree from project by path

SEE ALSO
  flo list
  flo prune

EXIT CODES
  0    Success
  1    Error - worktree not found or removal failed

```

### `flo prune`

```

flo prune

Clean up Git metadata for manually deleted worktrees

FLAGS
  --project    Project to prune worktrees for (name or path). Names resolved via ~/.config/flo/settings.json


ABOUT

  Use this if you deleted with `rm -rf` instead of `flo rm`.
EXAMPLES
  flo prune    # Clean up metadata for current project
  flo prune --project backend    # Prune worktrees for different project (by name)

SEE ALSO
  flo list
  flo end

EXIT CODES
  0    Success

```
<!-- REFERENCE_END -->
## Development

See [DEVELOPMENT.md](DEVELOPMENT.md) for development instructions.
