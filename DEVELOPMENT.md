# Flo Development Guide

This document contains information for developers working on the flo project.

## Development Installation

For development, use symlinks so changes in the repo are immediately reflected:

```fish
~/projects/jasonkuhrt/flo/install-dev.fish
```

This creates symlinks instead of copying files, allowing you to work on the main branch and test changes immediately.

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

Install flo for production (copies files):
```fish
make install
```

Uninstall flo:
```fish
make uninstall
```

### Pre-commit Hooks

Install pre-commit hooks for automatic formatting:
```fish
make pre-commit
```

## Architecture

### Project Structure

```
functions/                       # Command directory
├── <command>.fish              # Top-level commands
├── <command>/                  # Subcommand directory (if applicable)
│   ├── <subcommand>.fish      # Individual subcommands
│   └── ...                    # More subcommands
├── helpers/                   # Helper functions
│   └── __flo_*.fish           # Internal helper functions
├── helpers.fish               # Helper loader
├── flo.fish                   # Main dispatcher
└── completions.fish           # Tab completions

scripts/                        # Development scripts
├── generate-docs.fish         # Documentation generator
├── format.fish               # Code formatter
└── check-format.fish         # Format checker

docs/                          # Generated documentation
├── README.md                 # Documentation index
└── reference/                # Command reference docs
    ├── <command>.md          # Individual command docs
    └── <command>/            # Subcommand docs
```

### Command Discovery

The documentation generator uses recursive discovery to find commands:

1. **Main Commands**: Discovered by parsing the dispatcher switch statement in `flo.fish`
2. **Subcommands**: Found by scanning `functions/<command>/` directories
3. **Special Cases**: Some commands like `claude --clean` are handled as pseudo-subcommands

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

## Adding Subcommands

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

## Testing Your Command

1. **Install in development mode**: `./install-dev.fish`
2. **Test all flag combinations**: Verify parsing works correctly
3. **Test error cases**: Ensure proper error messages
4. **Test help output**: Ensure help is clear and complete
5. **Test tab completion**: Verify completions work as expected
6. **Update documentation**: Run `make docs` to regenerate

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