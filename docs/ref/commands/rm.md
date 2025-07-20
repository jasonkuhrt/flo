# flo rm

```
Usage: flo rm [issue-number] [options]

Remove issue, pull request, and/or worktree.
By default, deletes the worktree but leaves issue and PR open.
If no issue number provided, shows interactive selection of removable items.

Arguments:
  issue-number    Issue number to remove (optional: shows selection if omitted)

Options:
  --close-issue         Close the GitHub issue (default: no)
  --close-pr            Close the pull request (default: no)
  --no-delete-worktree  Don't delete the worktree (default: delete)
  -f, --force           Skip confirmation prompt
  -h, --help            Show this help

Examples:
  flo rm                    Show interactive selection of items to remove
  flo rm 123                Delete worktree for issue #123
  flo rm --close-issue      Delete worktree and close issue
  flo rm --close-pr --close-issue  Delete worktree, close PR and issue
```
