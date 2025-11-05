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
                set -a commands $cmd
            end
        end
    end

    # Sort and return unique commands
    if test (count $commands) -gt 0
        printf '%s\n' $commands | sort -u
    end
end

function __cli_command_exists --description "Check if a CLI command exists"
    set -l cmd $argv[1]
    set -l func_name "$__cli_prefix"_"$cmd"
    functions -q $func_name
end

function __cli_get_command_description --description "Get description of a command"
    set -l cmd $argv[1]

    # Try to get description from co-located markdown file first
    set -l doc_file (__cli_find_command_doc $cmd)
    if test -n "$doc_file"
        set -l desc (__cli_parse_frontmatter "$doc_file" description)
        if test -n "$desc"
            echo $desc
            return 0
        end
    end

    # Fallback to function description
    set -l func_name "$__cli_prefix"_"$cmd"
    if functions -q $func_name
        set -l desc (type $func_name | string replace -rf ".*--description '(.*)'" '$1')
        if test -n "$desc"
            echo $desc
        else
            echo "No description available"
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

function __cli_get_command_aliases --description "Get aliases for a command from frontmatter"
    set -l cmd $argv[1]
    set -l doc_file (__cli_find_command_doc $cmd)

    if test -z "$doc_file"
        return 1
    end

    # Extract JSON frontmatter
    set -l json (sed -n '/^---$/,/^---$/p' "$doc_file" | sed '1d;$d' 2>/dev/null)
    if test -z "$json"
        return 1
    end

    # Parse aliases array (returns empty if not present)
    echo "$json" | jq -r '.aliases[]?' 2>/dev/null
end
