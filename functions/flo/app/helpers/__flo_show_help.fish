function __flo_show_help --description "Display standardized help text for flo commands"
    argparse --name="__flo_show_help" \
        u/usage= \
        d/description= \
        a/args= \
        o/options= \
        e/examples= \
        -- $argv; or return

    # Usage line (required)
    if set -q _flag_usage
        echo "Usage: $_flag_usage"
        echo ""
    end

    # Description (required)
    if set -q _flag_description
        echo "$_flag_description"
        echo ""
    end

    # Arguments section (optional)
    if set -q _flag_args
        echo "Arguments:"
        # Handle both literal newlines and \n escape sequences
        echo "$_flag_args" | while read -l line
            if test -n "$line"
                echo "  $line"
            end
        end
        echo ""
    end

    # Options section (optional)
    if set -q _flag_options
        echo "Options:"
        # Handle both literal newlines and \n escape sequences
        echo "$_flag_options" | while read -l line
            if test -n "$line"
                echo "  $line"
            end
        end
        echo ""
    end

    # Examples section (optional)
    if set -q _flag_examples
        echo "Examples:"
        # Handle both literal newlines and \n escape sequences
        echo "$_flag_examples" | while read -l line
            if test -n "$line"
                echo "  $line"
            end
        end
        echo ""
    end

    return 0
end
