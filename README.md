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

## Requirements

### Required

- **Fish shell** (3.0+)
- **git** and **GitHub CLI** (`gh`)
- **gum** - for interactive UI components ([github.com/charmbracelet/gum](https://github.com/charmbracelet/gum))
  - macOS: `brew install gum`
  - Other platforms: See [installation guide](https://github.com/charmbracelet/gum#installation)

### Optional (Recommended)

These tools enhance the flo experience but will fall back to standard alternatives if not installed:

- **fd** - Fast and user-friendly alternative to `find` ([github.com/sharkdp/fd](https://github.com/sharkdp/fd))
  - macOS: `brew install fd`
  - Provides: Faster file searching, respects .gitignore by default
- **bat** - A `cat` clone with syntax highlighting ([github.com/sharkdp/bat](https://github.com/sharkdp/bat))
  - macOS: `brew install bat`
  - Provides: Syntax-highlighted file viewing
- **delta** - A syntax-highlighting pager for git diffs ([github.com/dandavison/delta](https://github.com/dandavison/delta))
  - macOS: `brew install git-delta`
  - Provides: Beautiful, side-by-side diffs with syntax highlighting

Install all optional tools on macOS:

```bash
brew install fd bat git-delta
```

## Installation

### Using Fisher

[Fisher](https://github.com/jorgebucaran/fisher) is the recommended way to install flo:

```fish
fisher install jasonkuhrt/flo
```

**Why Fisher?**

- Clean installation and removal
- Automatic updates with `fisher update`
- Proper Fish shell integration
- No manual file management

### First-time Fisher Setup

If you don't have Fisher installed:

```fish
# Install Fisher
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher

# Then install flo
fisher install jasonkuhrt/flo
```

### Managing flo

```fish
# Update flo to the latest version
fisher update jasonkuhrt/flo

# Remove flo
fisher remove jasonkuhrt/flo
```

<details>
<summary>Manual Installation (Not Recommended)</summary>

Only use this if you cannot use Fisher:

1. Clone this repository:
   ```fish
   git clone https://github.com/jasonkuhrt/flo.git ~/projects/jasonkuhrt/flo
   cd ~/projects/jasonkuhrt/flo && make install
   ```

2. Restart your Fish shell or run:
   ```fish
   source ~/.config/fish/config.fish
   ```

**To uninstall manually:**

```fish
cd ~/projects/jasonkuhrt/flo && make uninstall
```

</details>

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

## Documentation

Complete command documentation is available in the [docs/](docs/) directory, automatically generated from flo's internal help system.

- **[Main Documentation](docs/README.md)** - Architecture and overview
- **[Command Reference](docs/ref/commands/)** - Complete command documentation

## Development

For development information, including adding new commands, testing, and contributing guidelines, see [DEVELOPMENT.md](DEVELOPMENT.md).
