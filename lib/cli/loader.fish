# Module loading functions

function __cli_load_commands --description "Load all command files from a directory"
    set -l dir $argv[1]
    set -l exclude $argv[2..-1]

    if not test -d "$dir"
        __cli_error "Command directory not found: $dir"
        return 1
    end

    # Load all .fish files except excluded ones
    for file in "$dir"/*.fish
        if not test -f "$file"
            continue
        end

        set -l basename (basename "$file" .fish)

        # Skip excluded files
        if __cli_contains $basename $exclude
            continue
        end

        # Skip hidden files
        if string match -q ".*" $basename
            continue
        end

        # Source the file
        source "$file"
    end
end

function __cli_reload --description "Reload all CLI commands"
    # Get current CLI settings
    set -l name $__cli_name
    set -l prefix $__cli_prefix
    set -l dir $__cli_dir
    set -l description $__cli_description
    set -l version $__cli_version

    # Find and remove all command functions
    for func in (functions -n | string match "$prefix"_"*")
        functions -e $func
    end

    # Reload all commands
    __cli_load_commands $dir $name helpers completions

    echo "Reloaded all $name commands"
end
