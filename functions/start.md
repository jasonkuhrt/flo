---
{
  "description": "Start work by creating a worktree from an issue or branch",
  "parametersPositional": [
    {
      "name": "issue-or-branch",
      "description": "GitHub issue number or branch name (optional - shows interactive picker if omitted)",
      "required": false
    }
  ],
  "parametersNamed": [
    {
      "name": "--project",
      "description": "Project to operate on (name or path). Names resolved via ~/.config/flo/settings.json"
    },
    {
      "name": "--claude",
      "description": "Open Zed and launch 'claude /start' in the current terminal"
    }
  ],
  "examples": [
    {
      "command": "flo start",
      "description": "Interactive issue selection (requires gum)"
    },
    {
      "command": "flo start 123",
      "description": "Create from GitHub issue"
    },
    {
      "command": "flo start 123 --project kit",
      "description": "Create in different project (by name)"
    },
    {
      "command": "flo start 123 --project ~/projects/backend",
      "description": "Create in different project (by path)"
    },
    {
      "command": "flo start #123",
      "description": "Create from GitHub issue (# is optional)"
    },
    {
      "command": "flo start feat/new-feature",
      "description": "Create from branch name"
    },
    {
      "command": "flo start 123 --claude",
      "description": "Create from issue, open Zed, and launch Claude session"
    }
  ],
  "related": ["end", "list", "prune"],
  "exitCodes": {
    "0": "Success",
    "1": "Error - GitHub API failure, worktree creation failed, or missing dependencies"
  }
}
---

# WORKTREE ORGANIZATION

Flo creates worktrees as siblings to your main project:
  ~/projects/myproject/                      (main repo on main branch)
  ~/projects/myproject_feat-123-add-auth/    (worktree for feat/123-add-auth)
  ~/projects/myproject_fix-456-bug-fix/      (worktree for fix/456-bug-fix)

Running flo multiple times for the same branch is safe - it updates Claude context without recreating the worktree.

# CROSS-PROJECT MANAGEMENT

Use `--project` to manage worktrees across multiple projects without changing directories.

**Setup** (one-time):

Configure project directories in `~/.config/flo/settings.json`:

```json
{
  "projectsDirectories": [
    "~/projects/*/*",
    "~/work/*"
  ]
}
```

**Usage:**

```bash
# From anywhere, create worktree in different project:
flo start 123 --project kit
flo start 456 --project backend

# Fuzzy matching:
flo start 123 --project api
# Matches: ~/projects/jasonkuhrt/api-server

# Multiple matches → interactive picker (requires gum):
flo start 123 --project flo
# Shows picker: [flo, flo-legacy, workflow]
```

**Path Resolution:**

- **Bare name:** `--project backend` → fuzzy match in configured directories
- **Absolute path:** `--project ~/projects/backend` → use directly
- **Relative path:** `--project ./backend` or `--project ../backend` → resolve from pwd

**Without Settings:**

If `projectsDirectories` not configured, bare names fail with helpful message:

```bash
flo start 123 --project backend
# ✗ Cannot resolve 'backend'
#
# Configure ~/.config/flo/settings.json or use explicit path:
#   --project ~/projects/backend
#   --project ./backend
```

# INTERACTIVE SELECTION

When you run `flo` with no arguments:
  1. Fetches up to 100 open issues from GitHub
  2. Shows interactive picker:
       - `→ Custom branch...` option at top for branch mode
       - Uses `gum filter` (fuzzy search) for >10 issues
       - Uses `gum choose` (simple list) for ≤10 issues
  3. Creates worktree for selected issue (or custom branch)

Requirements:
  - gum: https://github.com/charmbracelet/gum (install with: `brew install gum`)
  - gh CLI: https://cli.github.com (install with: `brew install gh`)

Fallback: If gum or gh are not installed, shows error with install instructions.

# BRANCH MODE

When you run `flo <branch-name>`:
  1. Creates worktree with the exact branch name you provide
  2. No GitHub integration (no issue fetching, no auto-assign)
  3. No Claude context files generated
  4. Perfect for: experiments, quick fixes, non-issue work

Examples:
  flo feat/experiment        # Creates feat/experiment branch
  flo fix/quick-bug          # Creates fix/quick-bug branch
  flo spike/new-tech         # Creates spike/new-tech branch

# ISSUE MODE

When you run `flo 123`:
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
  6. Generates .claude/issue.md with issue context
  7. Runs pnpm install
  8. Ready to code!

# CLAUDE INTEGRATION

When you create a worktree from an issue, flo:
  1. Generates `.claude/issue.md` with issue context
  2. Adds `.claude/issue.md` to `.gitignore`
  3. Auto-adds `@.claude/issue.md` import to project's CLAUDE.md (if exists)

The @-import is added automatically:
  - Root `CLAUDE.md` → adds `@.claude/issue.md`
  - `.claude/CLAUDE.md` → adds `@issue.md` (relative path)
  - No CLAUDE.md → silently skips
  - Already has import → idempotent, skips

.claude/issue.md (per-issue):
  - Contains GitHub issue context (title, description, comments)
  - Overwritten each run with fresh issue data
  - Gitignored - never committed
  - Worktree-specific

# SERENA MCP INTEGRATION

If you're using Serena MCP (github.com/oraios/serena) for semantic code analysis:
  - Flo automatically copies .serena/cache/ to new worktrees
  - Avoids re-indexing symbols (can save minutes on large projects)
  - Only happens when creating new worktrees (not when reusing)
  - Requires .serena/cache/ to exist in your main project
  - Pre-index once: uvx --from git+https://github.com/oraios/serena serena project index
