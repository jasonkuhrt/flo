# flo claude

```
Usage: flo claude [options]

Generate Claude context files for current or all worktrees.

Options:
  -h, --help    Show this help message
  -a, --all     Generate context for all worktrees
  -c, --clean   Clean up old context files
  Environment Variables:
    FLO_CLAUDE_DIR    Directory to save context files (default: current directory)

Examples:
  flo claude                # Generate context for current worktree
  flo claude --all          # Generate context for all worktrees
  flo claude --clean        # Clean old context files
  export FLO_CLAUDE_DIR=~/Documents/claude-contexts
  flo claude                # Save to custom directory
```
