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
        for arg in (string split \n $_flag_args)
            echo "  $arg"
        end
        echo ""
    end

    # Options section (optional)
    if set -q _flag_options
        echo "Options:"
        for option in (string split \n $_flag_options)
            echo "  $option"
        end
        echo ""
    end

    # Examples section (optional)
    if set -q _flag_examples
        echo "Examples:"
        for example in (string split \n $_flag_examples)
            echo "  $example"
        end
        echo ""
    end

    return 0
end
