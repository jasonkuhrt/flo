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
    if __flo_has_command fd
        set -l fd_args

        # Add type flag
        if test "$type" = f
            set -a fd_args --type file
        else if test "$type" = d
            set -a fd_args --type directory
        end

        # Add pattern if provided
        if test -n "$pattern"
            set -a fd_args "$pattern"
        end

        # Add path
        set -a fd_args "$path"

        # Add max depth if specified
        if test -n "$max_depth"
            set -a fd_args --max-depth "$max_depth"
        end

        # Handle hidden files
        if test $exclude_hidden -eq 1
            set -a fd_args --no-hidden
        else
            set -a fd_args --hidden
        end

        # Execute fd
        fd $fd_args 2>/dev/null
    else
        # Fall back to find
        set -l find_args "$path"

        # Add max depth if specified
        if test -n "$max_depth"
            set -a find_args -maxdepth "$max_depth"
        end

        # Add type
        set -a find_args -type "$type"

        # Add pattern if provided
        if test -n "$pattern"
            set -a find_args -name "$pattern"
        end

        # Execute find and filter hidden files if needed
        if test $exclude_hidden -eq 1
            find $find_args 2>/dev/null | grep -v '/\.'
        else
            find $find_args 2>/dev/null
        end
    end
end
