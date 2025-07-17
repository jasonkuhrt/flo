# flo next

```
Usage: flo next [issue-number]

Context-aware next issue command:
- In worktree: transition workflow (delete → sync → create → claude)
- In main project: regular issue workflow (create → claude)

Options:
  --no-claude   Skip Claude launch
  -h, --help    Show this help

Examples:
  flo next              Select from issue list
  flo next 123          Work on issue #123
  flo next 123 --no-claude  Work on issue #123 without Claude
```
