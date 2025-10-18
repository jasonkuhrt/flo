# Fish CLI Framework

A reusable framework for building command-line interfaces in Fish shell.

## Features

- **Dynamic Command Discovery**: Automatically finds and loads commands
- **Co-located Documentation**: Markdown files next to command files with JSON frontmatter
- **Automated Help Generation**: Auto-generates help from frontmatter (title, usage, parameters, guide)
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
function myapp_status
    # Your command implementation
end
```

### Creating Documentation

Co-locate a markdown file next to each command with JSON frontmatter:

```fish
# File: status.md
---
{
  "description": "Show app status",
  "namedParameters": [
    {
      "name": "format",
      "description": "Output format (json, text)"
    }
  ]
}
---

Additional guide content goes here.

This will appear in the "Guide" section of the help output.
```

**Frontmatter Fields:**

- `description` (string, required): Short description shown in command list
- `namedParameters` (array, optional): Named parameters for the command
  - Each parameter object supports:
    - `name` (string, required): Parameter name
    - `description` (string, required): Parameter description
    - `required` (boolean, optional): If `true`, framework validates parameter is provided
- `positionParameters` (boolean, optional): Set to `true` if command accepts positional arguments

**What the framework auto-generates from frontmatter:**

1. **Title**: `# <cli-name> <command>`
2. **Usage**: Code block with command signature including parameters
3. **Parameters**: List of named parameters with descriptions
4. **Guide**: Markdown content after frontmatter

**Automatic framework features:**
- The framework automatically intercepts `--help` and `-h` flags
- The framework validates required parameters before calling commands
- Commands never see help flags or invalid parameter counts
- No need to add help or validation code to your commands

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
Get the description of a command from co-located markdown frontmatter.

### Documentation Functions

#### `__cli_find_command_doc`
Find the co-located markdown file for a command.

Returns the path to the `.md` file if it exists next to the `.fish` file.

#### `__cli_parse_frontmatter`
Parse a field from JSON frontmatter in a markdown file.

```fish
__cli_parse_frontmatter <file> <key>
```

#### `__cli_render_command_help`
Render formatted help output for a command from its markdown file.

Auto-generates:
- Title
- Usage section with parameters
- Parameters list (if namedParameters defined)
- Guide section from markdown content

#### `__cli_get_markdown_content`
Extract markdown content after frontmatter delimiters.

### Helper Functions

#### `__cli_reload`
Reload all commands (useful for development).

## Example CLI

**Main file (myapp.fish):**

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

**Command file (commands/build.fish):**

```fish
function myapp_build
    set -l target $argv[1]

    echo "Building $target..."
    make $target
end
```

**Documentation file (commands/build.md):**

```markdown
---
{
  "description": "Build the project",
  "namedParameters": [
    {
      "name": "target",
      "description": "Build target (debug, release, all)",
      "required": true
    }
  ]
}
---

Builds the project using make.

Examples:
- `myapp build debug`
- `myapp build release`
```

**Results:**

Running `myapp build --help` auto-generates help:

```
# myapp build

## Usage

```fish
myapp build <target>
```

## Parameters

- **target** - Build target (debug, release, all)

## Guide

Builds the project using make.

Examples:
- `myapp build debug`
- `myapp build release`
```

Running `myapp build` without arguments automatically validates and shows:

```
Error: Missing required parameters

Usage: myapp build <target>
Run 'myapp build --help' for more information
```

No validation code needed in your command function!

## Benefits

1. **Consistency**: All CLIs follow the same patterns
2. **Maintainability**: Less code to maintain
3. **Discoverability**: Commands are auto-discovered
4. **Extensibility**: Easy to add new features
5. **Reusability**: Use for multiple CLI projects