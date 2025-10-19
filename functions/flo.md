---
{
  "description": "Create worktree from branch or GitHub issue",
  "namedParameters": [
    {
      "name": "issue-or-branch",
      "description": "GitHub issue number or branch name",
      "required": true
    }
  ]
}
---

# WORKTREE ORGANIZATION

Flo creates worktrees as siblings to your main project:
  ~/projects/myproject/                      (main repo on main branch)
  ~/projects/myproject_feat-123-add-auth/    (worktree for feat/123-add-auth)
  ~/projects/myproject_fix-456-bug-fix/      (worktree for fix/456-bug-fix)

Running flo multiple times for the same branch is safe - it updates Claude context without recreating the worktree.

# ISSUE MODE

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

# CLAUDE INTEGRATION

When you create a worktree from an issue, flo uses a two-file system:

.claude/CLAUDE.md (one-time):
  - Instructs Claude to read .claude/CLAUDE.local.md
  - Prepended to existing CLAUDE.md if present
  - Committed to your repo

.claude/CLAUDE.local.md (per-issue):
  - Overwritten each run with issue context
  - Gitignored - never committed
  - Worktree-specific

# SERENA MCP INTEGRATION

If you're using Serena MCP (github.com/oraios/serena) for semantic code analysis:
  - Flo automatically copies .serena/cache/ to new worktrees
  - Avoids re-indexing symbols (can save minutes on large projects)
  - Only happens when creating new worktrees (not when reusing)
  - Requires .serena/cache/ to exist in your main project
  - Pre-index once: uvx --from git+https://github.com/oraios/serena serena project index

# EXAMPLES

flo 123                    Create from GitHub issue
flo #123                   Create from GitHub issue (# is optional)
flo feat/new-feature       Create from branch name
