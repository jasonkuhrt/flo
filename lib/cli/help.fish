# Help system for CLI framework

function __cli_setup_help --description "Set up the help system"
    set -l cli_name $argv[1]
    set -l prefix $argv[2]

    # Nothing to set up currently, but this is where we could
    # register help formatters, themes, etc.
end

function __cli_show_help --description "Show main help for the CLI"
    # Header
    echo "$__cli_name - $__cli_description"
    echo ""
    echo "Usage: $__cli_name <command> [options]"
    echo ""

    # Commands section
    echo "Commands:"
    set -l commands (__cli_get_commands)

    if test (count $commands) -gt 0
        for cmd in $commands
            set -l desc (__cli_get_command_description $cmd)
            printf "  %-15s %s\n" $cmd "$desc"
        end
    else
        echo "  No commands available"
    end

    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --version  Show version information"
    echo ""
    echo "Run '$__cli_name <command> --help' for command-specific help"
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
