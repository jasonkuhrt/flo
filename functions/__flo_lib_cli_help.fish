# Help system for CLI framework

function __cli_setup_help --description "Set up the help system"
    set -l cli_name $argv[1]
    set -l prefix $argv[2]

    # Nothing to set up currently, but this is where we could
    # register help formatters, themes, etc.
end

function __cli_show_help --description "Show main help for the CLI"
    set -l doc_file (__cli_find_command_doc $__cli_name)

    if test -n "$doc_file"
        # Use new glow rendering
        __cli_render_command_help "$__cli_name" "$doc_file"
    else
        # No .md file - show minimal help
        echo ""
        echo "No documentation available for $__cli_name"
        echo "Run: $__cli_name <command> --help"
    end
end

function __cli_show_command_help --description "Show help for a specific command"
    set -l cmd $argv[1]
    set -l usage $argv[2]
    set -l description $argv[3]
    set -l options $argv[4]
    set -l examples $argv[5]

    # Command name and description
    echo "$__cli_name $cmd - $description"
    echo ""

    # Usage
    if test -n "$usage"
        echo "Usage: $usage"
    else
        echo "Usage: $__cli_name $cmd [options]"
    end
    echo ""

    # Options
    if test -n "$options"
        echo "Options:"
        echo "$options"
        echo ""
    end

    # Examples
    if test -n "$examples"
        echo "Examples:"
        echo "$examples"
        echo ""
    end
end
