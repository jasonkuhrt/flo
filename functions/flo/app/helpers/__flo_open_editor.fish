function __flo_open_editor --description "Open the configured editor"
    set -l dir $argv[1]

    if __flo_has_command code
        code "$dir"
    else if __flo_has_command cursor
        cursor "$dir"
    else
        echo "No supported editor found (VSCode or Cursor)"
        return 1
    end
end
