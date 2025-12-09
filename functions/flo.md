---
{
  "description": "Create worktree from branch or GitHub issue (shorthand for `flo start`)",
  "parametersPositional": [
    {
      "name": "issue-or-branch",
      "description": "GitHub issue number or branch name (optional - shows interactive picker if omitted)",
      "required": false
    }
  ],
  "examples": [
    {
      "command": "flo",
      "description": "Interactive issue selection (requires gum)"
    },
    {
      "command": "flo 123",
      "description": "Create from GitHub issue"
    },
    {
      "command": "flo #123",
      "description": "Create from GitHub issue (# is optional)"
    },
    {
      "command": "flo feat/new-feature",
      "description": "Create from branch name"
    }
  ],
  "related": ["start", "end", "list", "prune"],
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

# INTERACTIVE SELECTION

When you run `flo` with no arguments:
  1. Fetches up to 100 open issues from GitHub
  2. Shows interactive picker:
       - Uses `gum filter` (fuzzy search) for >10 issues
       - Uses `gum choose` (simple list) for ≤10 issues
  3. Creates worktree for selected issue

Requirements:
  - gum: https://github.com/charmbracelet/gum (install with: `brew install gum`)
  - gh CLI: https://cli.github.com (install with: `brew install gh`)

Fallback: If gum or gh are not installed, shows help message instead.

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
  6. Generates CLAUDE.local.md with issue context
  7. Runs pnpm install
  8. Ready to code!

# CLAUDE INTEGRATION

When you create a worktree from an issue, flo generates `CLAUDE.local.md` in the
project root. Claude Code automatically reads this file when starting a session.

CLAUDE.local.md (per-issue):
  - Contains GitHub issue context (title, description, comments)
  - Overwritten each run with fresh issue data
  - Auto-gitignored by Claude Code
  - Worktree-specific

# SERENA MCP INTEGRATION

If you're using Serena MCP (github.com/oraios/serena) for semantic code analysis:
  - Flo automatically copies .serena/cache/ to new worktrees
  - Avoids re-indexing symbols (can save minutes on large projects)
  - Only happens when creating new worktrees (not when reusing)
  - Requires .serena/cache/ to exist in your main project
  - Pre-index once: uvx --from git+https://github.com/oraios/serena serena project index
