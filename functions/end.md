---
{
  "description": "End your work by removing a worktree",
  "aliases": ["rm"],
  "parametersPositional": [
    {
      "name": "branch-name-or-issue",
      "description": "Branch name, issue number, or worktree directory name to remove (optional - defaults to current worktree)",
      "required": false
    }
  ],
  "parametersNamed": [
    {
      "name": "--force",
      "short": "-f",
      "description": "Force removal even with uncommitted changes, and force-delete branch (git branch -D)"
    },
    {
      "name": "--keep-branch",
      "short": "-k",
      "description": "Keep the branch after removing the worktree (by default, branch is deleted)"
    },
    {
      "name": "--yes",
      "short": "-y",
      "description": "Skip confirmation prompt (non-interactive mode)"
    },
    {
      "name": "--project",
      "description": "Project to operate on (name or path). Names resolved via ~/.config/flo/settings.json"
    }
  ],
  "examples": [
    {
      "command": "flo rm",
      "description": "Remove current worktree (interactive)"
    },
    {
      "command": "flo rm 1320",
      "description": "Remove by issue number"
    },
    {
      "command": "flo rm #1320",
      "description": "Remove by issue number (# is optional)"
    },
    {
      "command": "flo rm feat/123-add-auth",
      "description": "Remove by branch name"
    },
    {
      "command": "flo rm fix/memory-leak",
      "description": "Remove by branch name"
    },
    {
      "command": "flo rm myproject_feat-123-add-auth",
      "description": "Remove by worktree directory name"
    },
    {
      "command": "flo rm --yes",
      "description": "Remove current worktree without confirmation"
    },
    {
      "command": "flo rm -y",
      "description": "Short form of --yes"
    },
    {
      "command": "flo rm --force",
      "description": "Force remove current worktree"
    },
    {
      "command": "flo rm --force --yes",
      "description": "Force remove without confirmation (for automation)"
    },
    {
      "command": "flo rm 1320 --force",
      "description": "Force removal with uncommitted changes and force-delete branch"
    },
    {
      "command": "flo rm --keep-branch",
      "description": "Remove worktree but keep the branch"
    },
    {
      "command": "flo rm feat/test --keep-branch",
      "description": "Remove specific worktree but preserve the branch"
    },
    {
      "command": "flo end --project backend",
      "description": "Remove current worktree from different project"
    },
    {
      "command": "flo end 123 --project ~/projects/api",
      "description": "Remove worktree from project by path"
    }
  ],
  "related": ["list", "prune"],
  "exitCodes": {
    "0": "Success",
    "1": "Error - worktree not found or removal failed"
  }
}
---

# ABOUT

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
