# Fish CLI Framework

A reusable framework for building command-line interfaces in Fish shell.

## Features

- **Dynamic Command Discovery**: Automatically finds and loads commands
- **Consistent Help Generation**: Auto-generates help from function descriptions
- **Dependency Management**: Check and report missing dependencies
- **Zero Boilerplate**: Just write your command functions
- **Naming Convention Support**: Avoid conflicts with system commands

## Usage

### Basic Setup

```fish
# myapp.fish
source /path/to/cli/$.fish

# Initialize your CLI
__cli_init \
    --name myapp \
    --prefix myapp \
    --dir (dirname (status -f)) \
    --description "My awesome CLI tool"
```

### Creating Commands

Follow the naming convention:
- File: `<command>.fish`
- Function: `<prefix>_<command>`

```fish
# File: status.fish
function myapp_status --description "Show app status"
    # Your command implementation
end
```

### Registering Dependencies

```fish
# In your main file
__cli_register_deps status git curl
__cli_register_deps deploy docker kubectl
```

## API Reference

### Core Functions

#### `__cli_init`
Initialize a CLI application.

Options:
- `--name`: CLI command name (required)
- `--prefix`: Function prefix (defaults to name)
- `--dir`: Directory containing command files (required)
- `--description`: CLI description
- `--version`: CLI version
- `--exclude`: Files to exclude from loading

#### `__cli_register_deps`
Register dependencies for a command.

```fish
__cli_register_deps <command> <dep1> <dep2> ...
```

### Discovery Functions

#### `__cli_get_commands`
Get all available commands.

#### `__cli_command_exists`
Check if a command exists.

#### `__cli_get_command_description`
Get the description of a command.

### Helper Functions

#### `__cli_reload`
Reload all commands (useful for development).

## Example CLI

```fish
#!/usr/bin/env fish

# Initialize
source lib/cli/$.fish

__cli_init \
    --name myapp \
    --prefix myapp \
    --dir (dirname (status -f))/commands \
    --description "Example CLI application" \
    --version "1.0.0"

# Register dependencies
__cli_register_deps build make gcc
__cli_register_deps test pytest
__cli_register_deps deploy docker

# That's it! The framework handles everything else
```

## Benefits

1. **Consistency**: All CLIs follow the same patterns
2. **Maintainability**: Less code to maintain
3. **Discoverability**: Commands are auto-discovered
4. **Extensibility**: Easy to add new features
5. **Reusability**: Use for multiple CLI projects