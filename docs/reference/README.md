# flo

```
flo - Git workflow automation tool

Commands:
  issue <number|title>    Start work on a GitHub issue
  issue-create <title>    Create a new issue and start working on it
  next [number]           Transition to next issue (context-aware)
  rm [number]             Remove issue, PR, and/or worktree
  pr [create|push|checks|merge]  Manage pull requests
  worktree <create|delete|list|switch>  Manage git worktrees
  list <issues|prs|worktrees>  List various items
  status                  Show current worktree and PR status
  projects                List GitHub projects
  claude                  Add current branch context to Claude
  claude-clean            Remove old Claude context files
  help                    Show this help message
```

# flo Command Reference

This directory contains auto-generated documentation from flo's internal \`--help\` output.

## Main Command

The main flo help documentation is above.

## Commands

### Core Commands
- [issue](issue.md) - Work on GitHub issues
- [issue-create](issue-create.md) - Create new issue and start working
- [pr/](pr/) - Pull request management
  - [create](pr/create.md) - Create pull requests
  - [push](pr/push.md) - Push current branch
  - [checks](pr/checks.md) - Check PR status
  - [merge](pr/merge.md) - Merge pull requests
- [worktree/](worktree/) - Git worktree management
  - [create](worktree/create.md) - Create worktrees
  - [delete](worktree/delete.md) - Delete worktrees
  - [list](worktree/list.md) - List worktrees
  - [switch](worktree/switch.md) - Switch worktrees

### Browse Commands
- [list/](list/) - List various items
  - [issues](list/issues.md) - List GitHub issues
  - [prs](list/prs.md) - List pull requests
  - [worktrees](list/worktrees.md) - List worktrees
- [status](status.md) - Show status information
- [projects](projects.md) - List GitHub projects

### Workflow Commands
- [claude](claude.md) - Claude AI integration
- [next](next.md) - Context-aware next issue command

## Navigation

Commands with subcommands have their own directories:
- \`pr/\` - Pull request commands
- \`worktree/\` - Worktree commands
- \`list/\` - List commands

Each directory contains a README.md with an overview and links to subcommand documentation.
