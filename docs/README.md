# flo Documentation

Welcome to the flo documentation. flo is a Git workflow automation tool that integrates with GitHub for seamless issue and pull request management.

## Documentation Structure

- **[Command Reference](reference/)** - Complete command documentation generated from `--help` output
- **Installation** - See main [README.md](../README.md) for installation instructions
- **Getting Started** - See main [README.md](../README.md) for quick start guide

## Key Features

- **Issue Workflow** - Start work on GitHub issues with automatic worktree creation
- **Pull Request Management** - Create, push, and merge PRs with status checking
- **Worktree Management** - Manage Git worktrees with ease
- **Claude Integration** - Generate context for Claude AI assistance
- **Smart Completions** - Tab completion for all commands and GitHub data

## Architecture

flo is built with a modular architecture using Fish shell:

- **Domain-based modules** - Each feature area has its own file
- **Modern Fish patterns** - Uses native Fish operations for performance
- **Extensible design** - Easy to add new commands and features

## Command Overview

```
flo - Git workflow automation tool

Commands:
  issue <number|title>    Start work on a GitHub issue
  issue-create <title>    Create a new issue and start working on it
  pr [create|push|checks|merge]  Manage pull requests
  worktree <create|delete|list|switch>  Manage git worktrees
  list <issues|prs|worktrees>  List various items
  status                  Show current worktree and PR status
  projects                List GitHub projects
  claude                  Add current branch context to Claude
  claude-clean            Remove old Claude context files
  help                    Show this help message
```

For detailed command documentation, see the [Command Reference](reference/).

