function __flo_view_file --description "View a file with bat if available, otherwise use cat"
    set -l file_path $argv[1]
    set -l line_numbers $argv[2] # Optional: show line numbers

    if test -z "$file_path"
        echo "Usage: __flo_view_file <file_path> [--line-numbers]" >&2
        return 1
    end

    if not test -f "$file_path"
        echo "File not found: $file_path" >&2
        return 1
    end

    # Use bat if available
    if __flo_has_command bat
        set -l bat_args

        # Add line numbers if requested
        if test "$line_numbers" = --line-numbers
            set -a bat_args --number
        end

        # Use plain style for non-interactive output
        set -a bat_args --style=plain

        # Add file path
        set -a bat_args "$file_path"

        # Execute bat
        bat $bat_args
    else
        # Fall back to cat
        if test "$line_numbers" = --line-numbers
            cat -n "$file_path"
        else
            cat "$file_path"
        end
    end
end
