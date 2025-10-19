---
{
  "description": "Safely remove a git worktree by branch name or issue number",
  "namedParameters": [
    {
      "name": "branch-name-or-issue",
      "description": "Branch name or issue number of the worktree to remove",
      "required": true
    }
  ]
}
---

# ABOUT

Safely removes a worktree by branch name or issue number.
Calculates the path automatically and uses Git to properly
delete it. Always prefer this over 'rm -rf' to keep Git
state clean.

When given an issue number, finds the worktree created with
'flo <issue-number>' and removes it.

# EXAMPLES

flo rm 1320                  # Remove by issue number
flo rm #1320                 # Remove by issue number (# is optional)
flo rm feat/123-add-auth     # Remove by branch name
flo rm fix/memory-leak       # Remove by branch name
