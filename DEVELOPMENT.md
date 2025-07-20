# Flo Development Guide

This document contains information for developers working on the flo project.

## Development Installation

Flo provides two installation modes for different use cases:

### Development Mode (Recommended for Contributors)

For active development with instant feedback:

```fish
# Install with symlinks for instant updates
make install-dev
```

**Benefits:**

- **Instant feedback**: Changes to source files are immediately reflected
- **No update commands**: Edit code and test immediately
- **Same file structure**: Identical to Fisher installation

### Production Mode

For production use or testing Fisher compatibility:

```fish
# Install using Fisher
make install
```

**Benefits:**

- **Proper Fisher experience**: Same as end users get
- **Easy updates**: `fisher update jasonkuhrt/flo`
- **Clean uninstall**: `fisher remove jasonkuhrt/flo`

### Switching Between Modes

```fish
# Switch to development mode
make install-dev

# Switch back to Fisher mode  
make install
```

The development symlinks are automatically replaced when switching to Fisher mode.

## Command Naming Convention

Flo uses a consistent naming convention to avoid conflicts with system commands:

- **File name**: `<command>.fish` (e.g., `issue.fish`, `rm.fish`)
- **Function name**: `flo_<command>` (e.g., `flo_issue`, `flo_rm`)

This allows us to have a command like `rm` without conflicting with the system's `rm` command.

### Example

File: `functions/status.fish`

```fish
function flo_status --description "Show repository status"
    # Implementation
end
```

This command would be invoked as: `flo status`

## CLI Framework

Flo uses a custom CLI framework (`functions/flo/lib/cli/`) that provides:

- **Dynamic command dispatch**: Commands are discovered automatically
- **Consistent help generation**: Help text is auto-generated from function descriptions
- **Dependency management**: Dependencies are checked before running commands
- **Modular architecture**: Easy to add new commands

The framework handles all the boilerplate, so new commands just need to follow the naming convention.

## Development Tasks

The project includes several development tasks managed through the Makefile:

### Documentation Generation

Regenerate documentation from help text:

```fish
make docs
```

Clean generated documentation:

```fish
make docs-clean
```

### Code Formatting

Format all Fish files:

```fish
make format
```

Check if Fish files are properly formatted:

```fish
make check-format
```

### Installation Tasks

Install flo for development (symlinks):

```fish
make install-dev
```

Install flo using Fisher (production mode):

```fish
make install
```

Switch between modes as needed - Fisher will automatically replace symlinks when switching to production mode.

### Pre-commit Hooks

Flo uses pre-commit hooks to automatically format code before commits. The configuration is in `.pre-commit-config.yaml`.

Install pre-commit hooks:

```fish
make pre-commit
```

**How it works:**

- When you commit, pre-commit automatically runs the hooks defined in `.pre-commit-config.yaml`
- Currently configured to run `fish_indent` to format all `.fish` files
- If files are reformatted, they're automatically staged and the commit proceeds
- **Changes to `.pre-commit-config.yaml` are automatically applied** - no need to reinstall

**Current hooks:**

- `fish-format`: Automatically formats Fish files using `fish_indent`

**Manual formatting:**
You can also format files manually without committing:

```fish
make format
```

## Architecture

### Project Structure

```
functions/                       # Fisher-compatible structure
├── flo.fish                    # Main entry point
├── flo/                        # Private flo directory
│   ├── app/                    # Application code
│   │   ├── commands/           # Command implementations
│   │   │   ├── <command>.fish  # Individual commands
│   │   │   └── ...             # More commands
│   │   └── helpers/            # Helper functions
│   │       └── __flo_*.fish    # Internal helper functions
│   └── lib/                    # Library code
│       └── cli/                # CLI framework
│           ├── $.fish          # Framework entry point
│           ├── discovery.fish  # Command discovery
│           ├── help.fish       # Help system
│           └── ...             # Other framework files
├── completions.fish            # Top-level completions loader
├── errors.fish                 # Error handling
├── help.fish                   # Help system loader
└── helpers.fish                # Helper loader

completions/                    # Tab completions
└── flo.fish                   # Flo completions

scripts/                        # Development scripts
├── generate-docs.fish         # Documentation generator
├── format.fish               # Code formatter
└── check-format.fish         # Format checker

docs/                          # Generated documentation
├── README.md                 # Documentation index
└── ref/                      # Reference documentation
    └── commands/             # Command reference docs
        ├── <command>.md      # Individual command docs
        └── README.md         # Commands index
```

### Command Discovery

With the CLI framework, commands are discovered automatically:

1. **Main Commands**: Any function matching `flo_<command>` pattern
2. **Dynamic Loading**: All `.fish` files in `functions/` are loaded (except excluded ones)
3. **Auto Registration**: Commands appear in help automatically

## Adding New Commands

Adding new commands to flo is simple thanks to the CLI framework and naming convention:

### 1. Create the Command File

Create a new file in `functions/flo/app/commands/<command>.fish` with the function name `flo_<command>`:

```fish
# functions/flo/app/commands/mycommand.fish

function flo_mycommand --description "Brief description of what this command does"
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

### 2. Register Dependencies (Optional)

If your command requires external tools, add them to `functions/flo.fish`:

```fish
# Register command dependencies
__cli_register_deps mycommand git jq
```

That's it! The CLI framework automatically:

- Discovers your command
- Adds it to the help system
- Handles dispatch
- Checks dependencies

### 3. Add Tab Completions (Optional)

Add completions in `completions/flo.fish`:

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

## Command Conventions

### Naming Conventions

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

Use existing helper functions in `functions/flo/app/helpers/`:

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

## Adding Subcommands

For commands with subcommands, create a directory structure:

```
functions/flo/app/commands/
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

## Testing Your Command

1. **Install in development mode**: `make install-dev` (changes are instantly available)
2. **Test all flag combinations**: Verify parsing works correctly
3. **Test error cases**: Ensure proper error messages
4. **Test help output**: Ensure help is clear and complete
5. **Test tab completion**: Verify completions work as expected
6. **Test Fisher compatibility**: `make install` to verify production mode works
7. **Update documentation**: Run `make docs` to regenerate

## Debugging

### Common Issues

1. **Function not found**: Ensure the function is properly sourced in `flo.fish`
2. **Argument parsing errors**: Check `argparse` syntax and flag definitions
3. **Sourcing errors**: Verify all sourced files exist and have correct syntax
4. **Missing dependencies**: Check that required tools like `gh`, `gum`, `jq` are installed

### Useful Debug Commands

```fish
# Check if function is loaded
functions -q mycommand

# See function definition
functions mycommand

# Debug argument parsing
set -l test_args --flag --option value arg1 arg2
argparse --name="debug" h/help f/flag o/option= -- $test_args
echo "Parsed flags: $_flag_flag $_flag_option"
echo "Remaining args: $test_args"
```

## Contributing

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/my-feature`
3. **Make your changes** following the conventions above
4. **Test thoroughly** with development installation
5. **Update documentation** by running `make docs`
6. **Format code** by running `make format`
7. **Commit changes** with conventional commit messages
8. **Push to your fork** and create a pull request

## Code Style

- Use Fish shell idioms and best practices
- Follow existing patterns in the codebase
- Keep functions focused and single-purpose
- Use descriptive variable names
- Add comments for complex logic
- Always handle errors gracefully

## Release Process

1. **Update version** in relevant files
2. **Regenerate documentation**: `make docs`
3. **Test thoroughly** with both development and production installations
4. **Create release** following semantic versioning
5. **Update changelog** with notable changes
