# flo rm

```
Usage: flo rm [issue-number] [options]

Remove issue, pull request, and/or worktree.
By default, deletes the worktree but leaves issue and PR open.

Arguments:
  issue-number    Issue number to remove (default: current worktree's issue)

Options:

Examples:
  flo rm                    Delete current worktree, keep issue/PR open
  flo rm 123                Delete worktree for issue #123
  flo rm --close-issue      Delete worktree and close issue
  flo rm --close-pr --close-issue  Delete worktree, close PR and issue
```
