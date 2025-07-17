function __flo_select_file --description "Let user select a file using gum filter"
    set -l path $argv[1]
    set -l pattern $argv[2]

    # Default to current directory if no path provided
    if test -z "$path"
        set path "."
    end

    # Default pattern to all files
    if test -z "$pattern"
        set pattern "*"
    end

    # Check if fd is available for better file finding
    if command -q fd
        set -l files (fd --type f "$pattern" "$path" 2>/dev/null)
    else
        # Fallback to find
        set -l files (find "$path" -type f -name "$pattern" 2>/dev/null | grep -v "^\./\.")
    end

    if test -z "$files"
        echo "No files found matching pattern: $pattern" >&2
        return 1
    end

    # Always use filter for file selection as lists can be large
    set -l file_count (count $files)
    set -l selected (echo $files | tr ' ' '\n' | gum filter \
        --placeholder "Type to filter $file_count files..." \
        --header "Search files:" \
        --height 20)

    if test -z "$selected"
        return 1
    end

    echo $selected
end
