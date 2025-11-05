# CLI Framework - Auto Argument Parsing
# Automatically parse command arguments from JSON frontmatter in .md files

# Parse arguments for a command based on its frontmatter definition
# Usage: __cli_parse_args <command> [args...]
# Returns: Sets _flag_* variables in caller's scope (standard argparse behavior)
function __cli_parse_args
    set -l command $argv[1]
    set -l args $argv[2..-1]

    # Find the command's .md documentation file
    set -l doc_file (__cli_find_command_doc $command)
    if test -z "$doc_file"
        echo "Error: No documentation found for command: $command" >&2
        return 1
    end

    # Extract JSON frontmatter
    set -l json (sed -n '/^---$/,/^---$/p' "$doc_file" | sed '1d;$d')
    if test -z "$json"
        echo "Error: No frontmatter found in: $doc_file" >&2
        return 1
    end

    # Extract parametersNamed array from JSON
    set -l params_json (echo $json | jq -r '.parametersNamed // []')

    # Build argparse specification from JSON parameters
    set -l argparse_spec

    # Iterate through each parameter
    for param_json in (echo $params_json | jq -c '.[]')
        set -l param_name (echo $param_json | jq -r '.name' | string replace --regex '^--' '')
        set -l param_short (echo $param_json | jq -r '.short // empty' | string replace --regex '^-' '')
        set -l has_value (echo $param_json | jq -r 'if has("hasValue") then .hasValue else true end')
        set -l multiple (echo $param_json | jq -r 'if has("multiple") then .multiple else false end')

        # Build argparse format
        # Format: "short/long" or "short/long=" or "long=" or "short/long=+"
        set -l spec
        if test -n "$param_short"
            set spec "$param_short/$param_name"
        else
            set spec "$param_name"
        end

        # Add suffix based on parameter type
        if test "$has_value" = true
            if test "$multiple" = true
                # Multiple values: --tags x y z
                set spec "$spec=+"
            else
                # Single value: --file=value
                set spec "$spec="
            end
        end
        # else: Boolean flag, no suffix needed

        set -a argparse_spec $spec
    end

    # Execute argparse with generated specification
    if test (count $argparse_spec) -gt 0
        # Temporarily replace argv with our args for argparse to process
        set -l saved_argv $argv
        set argv $args

        argparse $argparse_spec -- $argv
        set -l argparse_status $status

        if test $argparse_status -ne 0
            set argv $saved_argv
            return $argparse_status
        end

        # Export all _flag_* variables to global scope so caller can access them
        for var in (set --names | string match '_flag_*')
            set -g $var $$var
        end

        # Update caller's argv with remaining positional arguments
        # (argv was modified by argparse to contain only unparsed args)
        set -g argv $argv
        return 0
    else
        # No flags defined, just pass through arguments
        return 0
    end
end
