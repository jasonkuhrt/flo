function __flo_find_files --description "Find files using fd if available, otherwise fall back to find"
    # Parse arguments
    set -l path "."
    set -l type f # f for files, d for directories
    set -l pattern ""
    set -l max_depth ""
    set -l exclude_hidden 1

    # Simple argument parsing
    for arg in $argv
        switch $arg
            case --type=\*
                set type (string replace --regex '^--type=' '' $arg)
            case --path=\*
                set path (string replace --regex '^--path=' '' $arg)
            case --pattern=\*
                set pattern (string replace --regex '^--pattern=' '' $arg)
            case --depth=\*
                set max_depth (string replace --regex '^--depth=' '' $arg)
            case --include-hidden
                set exclude_hidden 0
            case '*'
                # If no flag, treat as path
                if test -z "$path" -o "$path" = "."
                    set path $arg
                end
        end
    end

    # Use fd if available
    if command -q fd
        set -l fd_cmd fd

        # Add type flag
        if test "$type" = f
            set fd_cmd $fd_cmd --type file
        else if test "$type" = d
            set fd_cmd $fd_cmd --type directory
        end

        # Add pattern if provided
        if test -n "$pattern"
            set fd_cmd $fd_cmd "$pattern"
        end

        # Add path
        set fd_cmd $fd_cmd "$path"

        # Add max depth if specified
        if test -n "$max_depth"
            set fd_cmd $fd_cmd --max-depth "$max_depth"
        end

        # Handle hidden files
        if test $exclude_hidden -eq 1
            set fd_cmd $fd_cmd --no-hidden
        else
            set fd_cmd $fd_cmd --hidden
        end

        # Execute fd
        eval $fd_cmd 2>/dev/null
    else
        # Fall back to find
        set -l find_cmd find "$path"

        # Add max depth if specified
        if test -n "$max_depth"
            set find_cmd $find_cmd -maxdepth "$max_depth"
        end

        # Add type
        set find_cmd $find_cmd -type "$type"

        # Add pattern if provided
        if test -n "$pattern"
            set find_cmd $find_cmd -name "$pattern"
        end

        # Execute find and filter hidden files if needed
        if test $exclude_hidden -eq 1
            eval $find_cmd 2>/dev/null | grep -v '/\.'
        else
            eval $find_cmd 2>/dev/null
        end
    end
end
