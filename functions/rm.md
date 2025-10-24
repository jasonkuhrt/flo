---
{
  "description": "Safely remove a git worktree by branch name or issue number",
  "namedParameters": [
    {
      "name": "branch-name-or-issue",
      "description": "Branch name, issue number, or worktree directory name to remove",
      "required": true
    }
  ],
  "parametersNamed": [
    {
      "name": "--force",
      "short": "-f",
      "description": "Force removal even with uncommitted changes"
    }
  ],
  "examples": [
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
      "command": "flo rm 1320 --force",
      "description": "Force removal with uncommitted changes"
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
Calculates the path automatically and uses Git to properly
delete it. Always prefer this over 'rm -rf' to keep Git
state clean.

When given an issue number, finds the worktree created with
'flo <issue-number>' and removes it.
