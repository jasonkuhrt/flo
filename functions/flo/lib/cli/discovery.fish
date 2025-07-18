# Command discovery functions

function __cli_get_commands --description "Get all available CLI commands"
    # Find all functions with the CLI prefix
    set -l prefix $__cli_prefix
    set -l commands

    for func in (functions -n)
        if string match -q "$prefix"_"*" $func
            # Extract command name
            set -l cmd (string replace "$prefix"_ "" $func)
            # Skip internal functions (those with __)
            if not string match -q "*__*" $cmd
                # Skip helper functions that end with known suffixes
                if not string match -q "*_clean" $cmd
                    set -a commands $cmd
                end
            end
        end
    end

    # Sort and return unique commands
    printf '%s\n' $commands | sort -u
end

function __cli_command_exists --description "Check if a CLI command exists"
    set -l cmd $argv[1]
    set -l func_name "$__cli_prefix"_"$cmd"
    functions -q $func_name
end

function __cli_get_command_description --description "Get description of a command"
    set -l cmd $argv[1]
    set -l func_name "$__cli_prefix"_"$cmd"

    # Check if function exists
    if not functions -q $func_name
        echo "No description available"
        return
    end

    # Get the function definition and extract the description
    set -l func_def (functions $func_name)
    set -l first_line (echo $func_def | head -1)

    # Extract description from function definition line
    if string match -q "*--description*" $first_line
        # Extract text between quotes after --description
        set -l desc (string replace -r '.*--description\s+"([^"]*)".*' '$1' $first_line)
        if test "$desc" != "$first_line"
            echo $desc
        else
            # Try single quotes
            set desc (string replace -r ".*--description\s+'([^']*)'\s*" '$1' $first_line)
            if test "$desc" != "$first_line"
                echo $desc
            else
                echo "No description available"
            end
        end
    else
        echo "No description available"
    end
end

function __cli_get_command_usage --description "Get usage info for a command"
    set -l cmd $argv[1]
    set -l func_name "$__cli_prefix"_"$cmd"

    # Try to extract usage from the function's help
    # This assumes commands follow the pattern of checking _flag_help
    # and calling a help function with usage info
    echo "$__cli_name $cmd [options]"
end
