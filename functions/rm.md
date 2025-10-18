---
{
  "description": "Safely remove a git worktree by branch name",
  "namedParameters": [
    {
      "name": "branch-name",
      "description": "Name of the branch whose worktree to remove",
      "required": true
    }
  ]
}
---

# ABOUT

Safely removes a worktree by branch name. Calculates
the path automatically and uses Git to properly delete
it. Always prefer this over 'rm -rf' to keep Git state
clean.

# EXAMPLES

flo rm feat/123-add-auth
flo rm fix/memory-leak
