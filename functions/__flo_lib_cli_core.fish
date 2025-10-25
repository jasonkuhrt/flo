# Core utilities for the CLI framework

# Check if a value is in a list
function __cli_contains --description "Check if a value is in a list"
    set -l value $argv[1]
    set -e argv[1]
    contains -- $value $argv
end

# Get the directory of the current CLI
function __cli_get_dir --description "Get the CLI directory"
    echo $__cli_dir
end

# Get the CLI name
function __cli_get_name --description "Get the CLI name"
    echo $__cli_name
end

# Get the CLI prefix
function __cli_get_prefix --description "Get the CLI prefix"
    echo $__cli_prefix
end

# Log a message with the CLI name
function __cli_log --description "Log a message with CLI context"
    echo "[$__cli_name] $argv"
end

# Error logging
function __cli_error --description "Log an error message"
    echo "[$__cli_name] Error: $argv" >&2
end

# Alias management
function __cli_build_alias_map --description "Build map of command aliases"
    # Global associative array: alias_name → actual_command
    # Stored as array of "alias:command" strings
    set -g __cli_alias_map

    # Get all commands
    set -l commands (__cli_get_commands)

    for cmd in $commands
        # Get aliases from frontmatter
        set -l aliases (__cli_get_command_aliases $cmd)

        for alias_name in $aliases
            # Store mapping: alias → actual command
            set -a __cli_alias_map "$alias_name:$cmd"
        end
    end
end

function __cli_resolve_alias --description "Resolve alias to actual command name"
    set -l input $argv[1]

    # Check if input is an alias
    for entry in $__cli_alias_map
        set -l parts (string split : $entry)
        if test "$parts[1]" = "$input"
            # Return actual command name
            echo $parts[2]
            return 0
        end
    end

    # Not an alias, return input unchanged
    echo $input
    return 0
end
