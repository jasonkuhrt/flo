---
{
  "description": "Create worktree from branch or GitHub issue",
  "positionParameters": true
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
  5. Sets up .claude/CLAUDE.md (one-time)
  6. Generates .claude/CLAUDE.local.md with issue context
  7. Runs pnpm install
  8. Ready to code!

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

# EXAMPLES

flo 123                    Create from GitHub issue
flo feat/new-feature       Create from branch name
