# flo Documentation

Welcome to the flo documentation. flo is a Git workflow automation tool that integrates with GitHub for seamless issue and pull request management.

## Documentation Structure

- **[Command Reference](ref/commands/)** - Complete command documentation generated from `--help` output
- **Installation** - See main [README.md](../README.md) for installation instructions
- **Getting Started** - See main [README.md](../README.md) for quick start guide

## Key Features

- **Issue Workflow** - Start work on GitHub issues with automatic worktree creation
- **Pull Request Creation** - Create PRs with automatic branch pushing
- **Workflow Automation** - Seamless transitions between issues with next command
- **Claude Integration** - Generate context for Claude AI assistance
- **Smart Completions** - Tab completion for all commands and GitHub data

## Command Structure

flo supports both top-level commands and subcommands:

```
flo <command>                    # Top-level command
flo <command> <subcommand>       # Subcommand
```

## Directory Structure

Commands are organized in the codebase as follows:

```
functions/                       # Command directory (should be renamed to commands/)
├── <command>.fish              # Top-level command
├── <command>/                  # Subcommand directory
│   ├── <subcommand>.fish      # Individual subcommand
│   └── ...                    # More subcommands
└── helpers/                   # Helper functions
    └── __flo_*.fish           # Internal helpers
```

## Command Definition Convention

All commands follow this consistent pattern:

```fish
function <command_name> --description "Brief description"
    argparse --name="flo <command>" h/help [flags...] -- $argv; or return
    
    if set -q _flag_help
        # Help text implementation
        return 0
    end
    
    # Command implementation
end
```

**Key conventions:**
- Commands are in `functions/<command>.fish` (or `functions/<command>/` for subcommands)
- All commands use `argparse --name="flo <command>"`
- All commands support `-h/--help` flag
- Commands are routed through the main dispatcher in `flo.fish`
- Help text is self-contained within each command
- Subcommands are organized in subdirectories

## Command Overview

```
flo - Git workflow automation tool

Usage: flo <command> [options]

Commands:
  claude          ./scripts/../functions/claude.fish
  claude_clean    ./scripts/../functions/claude.fish
  issue           ./scripts/../functions/issue.fish
  next            ./scripts/../functions/next.fish
  pr              ./scripts/../functions/pr.fish
  reload          ./scripts/../functions/reload.fish
  rm              ./scripts/../functions/rm.fish

Options:
  -h, --help     Show this help message
  -v, --version  Show version information

Run 'flo <command> --help' for command-specific help
```

For detailed command documentation, see the [Command Reference](ref/commands/).

## Recommended Improvements

1. **Rename directory**: `functions/` → `commands/`
2. **Implement proper subcommands**: `flo claude clean` instead of `flo claude --clean`
3. **Organize subcommands**: Move related commands into subdirectories
4. **Consistent naming**: Use subcommand structure instead of hyphenated commands

