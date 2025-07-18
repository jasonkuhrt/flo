# CLI command dispatcher

function __cli_create_dispatcher --description "Create the main CLI dispatcher"
    set -l cli_name $argv[1]
    set -l prefix $argv[2]

    # Create the main CLI function
    function $cli_name --description "$__cli_description"
        set -l cmd $argv[1]
        set -e argv[1]

        # Handle empty command or help
        switch $cmd
            case '' help --help -h
                __cli_show_help
                return 0
            case version --version -v
                __cli_show_version
                return 0
        end

        # Check if command exists
        if __cli_command_exists $cmd
            # Check dependencies if required
            if __cli_check_deps $cmd
                # Call the command function
                __cli_call_command $cmd $argv
            else
                return 1
            end
        else
            __cli_error "Unknown command: $cmd"
            echo "Run '$__cli_name help' for usage information"
            return 1
        end
    end
end

function __cli_call_command --description "Call a CLI command function"
    set -l cmd $argv[1]
    set -e argv[1]

    # Build the function name
    set -l func_name "$__cli_prefix"_"$cmd"

    # Call the function
    $func_name $argv
end

function __cli_show_version --description "Show CLI version"
    if set -q __cli_version
        echo "$__cli_name version $__cli_version"
    else
        echo "$__cli_name (no version set)"
    end
end
