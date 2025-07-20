# flo next

```
Usage: flo next [issue-number]

Context-aware next workflow command:
- In worktree: transition workflow (delete → sync → create → claude)
- In main project: regular workflow (create → claude)
- When no issues available: option to continue without issue

Arguments:
  issue-number    Optional issue number to work on

Options:
  --no-claude   Skip Claude launch
  -h, --help    Show this help

Examples:
  flo next              Select from issue list or continue without issue
  flo next 123          Work on issue #123
  flo next 123 --no-claude  Work on issue #123 without Claude
  No-issue workflow:
  When no GitHub issues are available, you can choose to continue without
  an issue. This creates a worktree with pattern: no-issue/YYYYMMDD-HHMMSS
```
