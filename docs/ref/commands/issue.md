# flo issue

```
Usage: flo issue <issue-number|issue-title>

Start work on a GitHub issue by creating a worktree and branch.

Arguments:
  issue-number|issue-title    GitHub issue number or search term

Options:
  -h, --help    Show this help message
  -z, --zed     Open worktree in Zed editor
  -c, --claude  Generate Claude context after creation

Examples:
  flo issue 123
  flo issue "Fix bug in parser"
  flo issue 123 --zed --claude
```
