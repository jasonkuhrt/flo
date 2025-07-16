# Flo

A GitHub issue-driven development workflow tool for Fish shell that integrates with Git worktrees, GitHub CLI, and Claude Code.

## Features

- **Issue-centric workflow**: `flo 123` creates worktrees for GitHub issues
- **Smart branch management**: Reuses existing branches when available
- **Project namespacing**: Organizes worktrees by project in `~/worktrees/<project>/`
- **GitHub integration**: Deep integration with `gh` CLI for issues and PRs
- **Claude integration**: Generates context files for Claude Code
- **Zed editor support**: Opens worktrees in Zed automatically
- **Comprehensive status**: Shows issue, PR, and worktree status

## Installation

### Standard Installation

1. Clone this repository:
   ```fish
   git clone https://github.com/jasonkuhrt/flo.git ~/projects/jasonkuhrt/flo
   ```

2. Run the install script:
   ```fish
   ~/projects/jasonkuhrt/flo/install.fish
   ```

3. Restart your Fish shell or run:
   ```fish
   source ~/.config/fish/config.fish
   ```

### Development Installation

For development, use symlinks so changes in the repo are immediately reflected:

```fish
~/projects/jasonkuhrt/flo/install-dev.fish
```

This creates symlinks instead of copying files, allowing you to work on the main branch and test changes immediately.

### Uninstallation

To remove flo from your system:

```fish
~/projects/jasonkuhrt/flo/uninstall.fish
```

## How Flo Works

### Worktree Management

Flo organizes all worktrees in a consistent structure:
```
~/worktrees/
  └── <project-name>/
      ├── issue/123
      ├── feature-xyz
      └── bugfix-abc
```

**Important**: Flo only manages worktrees within its designated structure (`~/worktrees/` by default). It does not detect or manage worktrees created manually in other locations. This design keeps your worktrees organized and prevents conflicts.

If you have existing worktrees in other locations, you can:
- Continue using them alongside flo
- Manually recreate them within flo's structure using `flo create`
- Keep project repositories and flo worktrees separate

## Usage

Get started with flo's issue-driven workflow:

```fish
# Work on issue #123
flo 123

# List worktrees for current project
flo list

# Create a feature branch worktree
flo create feature-xyz

# Check status of current worktree
flo status

# Create PR from current worktree
flo pr create

# Generate Claude context
flo claude
```

For complete command documentation, see the [generated documentation](docs/) or run `flo --help` for any command.

## Configuration

Set environment variables in your Fish config:

```fish
# Base directory for worktrees (default: ~/worktrees)
set -gx FLO_BASE_DIR ~/my-worktrees

# Branch prefix for new branches (default: claude/)
set -gx FLO_BRANCH_PREFIX feature/

# Issue branch prefix (default: issue/)
set -gx FLO_ISSUE_PREFIX bug/

# Default editor (default: zed)
set -gx FLO_EDITOR code
```

## Requirements

- Fish shell
- Git
- GitHub CLI (`gh`)
- Zed editor (optional, configurable)

## Documentation

Complete command documentation is available in the [docs/](docs/) directory, automatically generated from flo's internal help system.

- **[Main Documentation](docs/README.md)** - Architecture and overview
- **[Command Reference](docs/reference/)** - Complete command documentation

To regenerate documentation:
```fish
make docs
```

## License

MIT