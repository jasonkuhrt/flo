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

## Usage

### Basic Commands

- `flo <issue-number>` - Create/switch to worktree for GitHub issue
- `flo list` - List all worktrees (current project only if in git repo)
- `flo status` - Show current worktree/issue/PR status
- `flo create <name>` - Create new worktree
- `flo remove <name>` - Remove worktree
- `flo cd <name>` - Navigate to worktree

### Project Management

- `flo projects` - List all projects with worktrees
- `flo list --all` - List worktrees across all projects
- `flo status --project` - Show status for all worktrees in project

### GitHub Integration

- `flo issues` - List repository issues
- `flo pr create` - Create PR from current worktree
- `flo pr view` - View PR for current worktree
- `flo sync` - Sync worktree with upstream

### Claude Integration

- `flo claude` - Generate Claude context for current worktree
- `flo claude --all` - Generate context for all worktrees

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

## Examples

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

## License

MIT