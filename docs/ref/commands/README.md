# flo

```
flo - Git workflow automation tool

Usage: flo <command> [options]

Commands:
  claude          Generate Claude context files for current or all worktrees.
  issue           Start work on a GitHub issue by creating a worktree and branch.
  next            Context-aware next workflow command: - In worktree: transition workflow (delete → sync → create → claude) - In main project: regular workflow (create → claude) - When no issues available: option to continue without issue
  pr              Create a pull request for the current branch.
  rm              Remove issue, pull request, and/or worktree. By default, deletes the worktree but leaves issue and PR open. If no issue number provided, shows interactive selection of removable items.

Options:
  -h, --help     Show this help message
  -v, --version  Show version information

Run 'flo <command> --help' for command-specific help
```

# flo Command Reference

This directory contains auto-generated documentation from flo's internal \`--help\` output.

## Main Command

The main flo help documentation is above.

## Commands

- [claude](claude.md) - Generate Claude context files for current or all worktrees.
- [issue](issue.md) - Start work on a GitHub issue by creating a worktree and branch.
- [next](next.md) - Context-aware next workflow command: - In worktree: transition workflow (delete → sync → create → claude) - In main project: regular workflow (create → claude) - When no issues available: option to continue without issue
- [pr](pr.md) - Context-aware next workflow command: - In worktree: transition workflow (delete → sync → create → claude) - In main project: regular workflow (create → claude) - When no issues available: option to continue without issue
- [rm](rm.md) - Remove issue, pull request, and/or worktree. By default, deletes the worktree but leaves issue and PR open. If no issue number provided, shows interactive selection of removable items.
