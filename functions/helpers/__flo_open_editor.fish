function __flo_open_editor --description "Open the configured editor"
    set -l dir $argv[1]
    
    if command -v code >/dev/null
        code $dir
    else if command -v cursor >/dev/null
        cursor $dir
    else
        echo "No supported editor found (VSCode or Cursor)"
        return 1
    end
end