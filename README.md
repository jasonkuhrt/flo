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

## Adding New Commands

Flo uses a consistent command structure that makes adding new commands straightforward. Follow these steps:

### 1. Create the Command File

Create a new file in `functions/<command>.fish`:

```fish
# functions/mycommand.fish

function mycommand --description "Brief description of what this command does"
    argparse --name="flo mycommand" h/help f/flag l/long-flag= o/option= -- $argv; or return
    
    if set -q _flag_help
        echo "Usage: flo mycommand [options] [arguments]"
        echo ""
        echo "Detailed description of what this command does."
        echo ""
        echo "Arguments:"
        echo "  argument1    Description of first argument"
        echo "  argument2    Description of second argument (optional)"
        echo ""
        echo "Options:"
        echo "  -f, --flag           Boolean flag description"
        echo "  -l, --long-flag      Another flag description"
        echo "  -o, --option VALUE   Option that takes a value"
        echo "  -h, --help           Show this help message"
        echo ""
        echo "Examples:"
        echo "  flo mycommand arg1 arg2"
        echo "  flo mycommand --flag --option value"
        return 0
    end
    
    # Command implementation
    echo "Command implementation goes here"
    
    # Access parsed arguments
    echo "Remaining arguments: $argv"
    
    # Access flags (set -q _flag_name to check if flag was provided)
    if set -q _flag_flag
        echo "Flag was provided"
    end
    
    # Access options (variable _flag_option contains the value)
    if set -q _flag_option
        echo "Option value: $_flag_option"
    end
end
```

### 2. Add to Main Dispatcher

Add a case for your command in `functions/flo.fish`:

```fish
# In the switch statement, add:
case mycommand
    mycommand $argv
```

### 3. Add Command Help to Main Help

Update the help text in `functions/flo.fish`:

```fish
# In the help case, add:
echo "  mycommand [args]        Brief description of what this command does"
```

### 4. Add Tab Completions (Optional)

Add completions in `functions/completions.fish`:

```fish
# Main command completion
complete -c flo -f -n __fish_use_subcommand -a mycommand -d "Brief description"

# Flag completions
complete -c flo -f -n "__fish_seen_subcommand_from mycommand" -s f -l flag -d "Flag description"
complete -c flo -f -n "__fish_seen_subcommand_from mycommand" -s o -l option -d "Option description"

# Dynamic completions (if needed)
complete -c flo -f -n "__fish_seen_subcommand_from mycommand" -a "(__my_completion_function)"
```

### 5. Test Your Command

```fish
# Test the command
flo mycommand --help
flo mycommand arg1 arg2
flo mycommand --flag --option value

# Test tab completion
flo mycommand <TAB>
```

### 6. Update Documentation

The documentation will be automatically generated from your help text:

```fish
make docs
```

### Command Naming Conventions

- **Command names**: Use lowercase, descriptive names (`issue`, `pr`, `claude`)
- **File names**: Match the command name exactly (`mycommand.fish`)
- **Function names**: Match the command name exactly (`function mycommand`)
- **Flag names**: Use descriptive names (`--title`, `--draft`, `--force`)
- **Help format**: Follow the established pattern for consistency

### Argument Parsing Best Practices

1. **Always use `argparse`** with `--name="flo <command>"` for consistent error messages
2. **Always provide `h/help`** flag for help text
3. **Use descriptive flag names** (not just single letters)
4. **Provide both short and long forms** for common flags (`t/title`)
5. **Include examples** in help text
6. **Use `or return`** after argparse for proper error handling

### Helper Functions

Use existing helper functions in `functions/helpers/`:

```fish
# Check GitHub authentication
if not __flo_check_gh_auth
    return 1
end

# Get repository info
set -l repo_root (__flo_get_repo_root)
set -l org_repo (__flo_get_org_repo)

# Display styled output
__flo_success "Operation completed successfully"
__flo_error "Something went wrong"
__flo_info "Information message"
```

### Adding Subcommands

For commands with subcommands, create a directory structure:

```
functions/
├── mycommand.fish          # Main command
└── mycommand/
    ├── subcmd1.fish        # flo mycommand subcmd1
    └── subcmd2.fish        # flo mycommand subcmd2
```

Then implement subcommand routing in the main command:

```fish
function mycommand --description "Command with subcommands"
    set -l subcmd $argv[1]
    set -e argv[1]
    
    switch $subcmd
        case subcmd1
            mycommand_subcmd1 $argv
        case subcmd2
            mycommand_subcmd2 $argv
        case '*'
            echo "Unknown subcommand: $subcmd"
            echo "Available subcommands: subcmd1, subcmd2"
            return 1
    end
end
```

### Testing Your Command

1. **Install in development mode**: `./install-dev.fish`
2. **Test all flag combinations**: Verify parsing works correctly
3. **Test error cases**: Ensure proper error messages
4. **Test help output**: Ensure help is clear and complete
5. **Test tab completion**: Verify completions work as expected
6. **Update documentation**: Run `make docs` to regenerate

## License

MIT