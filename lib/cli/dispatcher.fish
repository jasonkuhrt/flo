# CLI command dispatcher

function __cli_create_dispatcher --description "Create the main CLI dispatcher"
    set -l cli_name $argv[1]
    set -l prefix $argv[2]

    # Create the main CLI function
    function $cli_name --description "$__cli_description"
        set -l cmd $argv[1]

        # Handle empty command or help
        switch $cmd
            case ''
                # Try interactive issue selection if available
                set -l main_func "$__cli_prefix"_start # e.g., flo_start
                set -l select_func "__"$__cli_prefix"_select_issue" # e.g., __flo_select_issue

                if functions -q $select_func
                    set -l selected_issue ($select_func)
                    if test $status -eq 0; and test -n "$selected_issue"
                        # Call main function with selected issue
                        $main_func $selected_issue
                        return $status
                    end
                end

                # Fallback to help if selection failed or not available
                __cli_show_help
                return 0
            case help --help -h
                __cli_show_help
                return 0
            case version --version -v
                __cli_show_version
                return 0
        end

        # Resolve alias to actual command name if applicable
        set -l actual_cmd (__cli_resolve_alias $cmd)

        # Check if command exists
        if __cli_command_exists $actual_cmd
            set -e argv[1]
            # Check dependencies if required
            if __cli_check_deps $actual_cmd
                # Call the command function
                __cli_call_command $actual_cmd $argv
            else
                return 1
            end
        else
            # Not a subcommand - try calling main command with all args
            set -l main_func "$__cli_prefix"_start # e.g., flo_start
            if functions -q $main_func
                $main_func $argv # Pass all args including first one
            else
                __cli_error "Unknown command: $cmd"
                echo "Run '$__cli_name help' for usage information"
                return 1
            end
        end
    end
end

function __cli_call_command --description "Call a CLI command function"
    set -l cmd $argv[1]
    set -e argv[1]

    # Check for --help flag
    if contains -- --help $argv; or contains -- -h $argv
        # Try to find and render co-located markdown documentation
        set -l doc_file (__cli_find_command_doc $cmd)
        if test -n "$doc_file"
            __cli_render_command_help $cmd "$doc_file"
            return 0
        else
            # Fallback to basic help if no doc file found
            echo "$__cli_name $cmd - "(__cli_get_command_description $cmd)
            echo ""
            echo "Usage: $__cli_name $cmd [options]"
            echo ""
            echo "No detailed documentation available."
            return 0
        end
    end

    # Validate required parameters from frontmatter
    set -l doc_file (__cli_find_command_doc $cmd)
    if test -n "$doc_file"
        # Extract JSON frontmatter
        set -l json (sed -n '/^---$/,/^---$/p' "$doc_file" | sed '1d;$d' 2>/dev/null)
        if test -n "$json"
            # Count required parameters
            set -l required_count (echo "$json" | jq -r '[.namedParameters[]? | select(.required == true)] | length' 2>/dev/null)
            if test -n "$required_count"; and test "$required_count" -gt 0
                set -l actual_count (count $argv)
                if test $actual_count -lt $required_count
                    # Get required parameter names for error message
                    set -l required_names (echo "$json" | jq -r '.namedParameters[]? | select(.required == true) | .name' 2>/dev/null | string collect)
                    set -l param_list (string split \n $required_names | string join '> <')

                    echo "Error: Missing required parameters"
                    echo ""
                    echo "Usage: $__cli_name $cmd <$param_list>"
                    echo "Run '$__cli_name $cmd --help' for more information"
                    return 1
                end
            end
        end
    end

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
