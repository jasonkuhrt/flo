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
