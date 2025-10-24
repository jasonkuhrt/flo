# Help system for CLI framework

function __cli_setup_help --description "Set up the help system"
    set -l cli_name $argv[1]
    set -l prefix $argv[2]

    # Nothing to set up currently, but this is where we could
    # register help formatters, themes, etc.
end

function __cli_show_help --description "Show main help for the CLI"
    # Leading newline for spacing
    echo ""

    # Title (just command name in cyan)
    set_color cyan
    echo "$__cli_name"
    set_color normal
    echo ""

    # Description paragraph
    if test -n "$__cli_description"
        echo "$__cli_description"
        echo ""
    end

    # Commands section
    set_color --dim black
    echo COMMANDS
    set_color normal
    set -l commands (__cli_get_commands)

    if test (count $commands) -gt 0
        for cmd in $commands
            set -l desc (__cli_get_command_description $cmd)
            printf "  %-10s %s\n" $cmd "$desc"
        end
    else
        echo "  No commands available"
    end

    echo ""
    set_color --dim black
    echo OPTIONS
    set_color normal
    echo "  -h, --help       Show this help message"
    echo "  -v, --version    Show version information"

    # Render positional parameters if they exist in the main command doc
    set -l doc_file (__cli_find_command_doc $__cli_name)
    if test -n "$doc_file"
        set -l json (__cli_parse_frontmatter "$doc_file")
        if test -n "$json"
            set -l param_count (echo "$json" | jq -r '.parametersPositional | length' 2>/dev/null)
            if test "$param_count" -gt 0
                echo ""
                set_color --dim black
                echo "POSITIONAL PARAMETERS"
                set_color normal
                echo "$json" | jq -r '.parametersPositional[] | "  <\(.name)>    \(.description)"' 2>/dev/null
            end
        end

        # Render guide content
        set -l guide_content (__cli_get_markdown_content "$doc_file")
        if test (count $guide_content) -gt 0
            __cli_render_markdown_sections $guide_content
        end
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
