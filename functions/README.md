# Flo Modules

This directory contains the refactored flo implementation, organized by domain.

## Structure

- `main.fish` - Main entry point with command dispatcher
- `help.fish` - All help documentation  
- `helpers.fish` - Shared utility functions
- `worktree.fish` - Git worktree management
- `issue.fish` - GitHub issue workflow
- `pr.fish` - Pull request management
- `browse.fish` - List/status/projects commands
- `claude.fish` - Claude AI integration
- `completions.fish` - Tab completions
- `loader.fish` - Loads all modules in correct order

## Usage

To use this refactored version, source the loader:
```fish
source ~/.config/fish/functions/flo/loader.fish
```

All the code uses modern Fish features discovered from the documentation analysis:
- `string` builtin instead of sed/grep
- `argparse` for argument handling
- `set -q` for existence checks
- Proper error handling with `$status`
- Function descriptions on all functions