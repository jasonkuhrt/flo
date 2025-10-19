---
{
  "description": "Safely remove a git worktree by branch name or issue number",
  "namedParameters": [
    {
      "name": "branch-name-or-issue",
      "description": "Branch name, issue number, or worktree directory name to remove",
      "required": true
    }
  ]
}
---

# ABOUT

Safely removes a worktree by branch name, issue number, or worktree directory name.
Calculates the path automatically and uses Git to properly
delete it. Always prefer this over 'rm -rf' to keep Git
state clean.

When given an issue number, finds the worktree created with
'flo <issue-number>' and removes it.

## FLAGS

--force, -f    Force removal even with uncommitted changes

# EXAMPLES

flo rm 1320                              # Remove by issue number
flo rm #1320                             # Remove by issue number (# is optional)
flo rm feat/123-add-auth                 # Remove by branch name
flo rm fix/memory-leak                   # Remove by branch name
flo rm myproject_feat-123-add-auth       # Remove by worktree directory name
flo rm 1320 --force                      # Force removal with uncommitted changes
