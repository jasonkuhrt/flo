# flo - Git workflow automation tool
# Fisher-compatible entry point with portable path resolution

function flo --description "Git workflow automation tool"
    # Use Fisher's portable path resolution
    set -q fisher_path; or set -l fisher_path $__fish_config_dir
    set -l flo_private "$fisher_path/functions/flo"

    # Development fallback: if we're in development, use the current directory
    if not test -d "$flo_private"
        set -l current_dir (dirname (status --current-filename))
        set flo_private "$current_dir/flo"
    end

    # Source library code (domain-agnostic)
    source "$flo_private/lib/cli/\$.fish"

    # Source application code (domain-specific)
    for file in $flo_private/app/**/*.fish
        source $file
    end

    # Initialize CLI framework
    __cli_init \
        --name flo \
        --prefix flo \
        --dir "$flo_private/app/commands" \
        --description "Git workflow automation tool" \
        --version "1.0.0"

    # Register command dependencies
    __cli_register_deps issue git gh gum jq
    __cli_register_deps pr git gh gum
    __cli_register_deps next git gh gum
    __cli_register_deps rm git gh gum
    __cli_register_deps claude git gh

    # The CLI framework creates the dispatcher, but we need to handle the dispatch ourselves
    # Handle empty command or help
    if test (count $argv) -eq 0; or test "$argv[1]" = help -o "$argv[1]" = --help -o "$argv[1]" = -h
        __cli_show_help
        return 0
    else if test "$argv[1]" = version -o "$argv[1]" = --version -o "$argv[1]" = -v
        __cli_show_version
        return 0
    end

    set -l cmd $argv[1]
    set -e argv[1]

    # Check if command exists and dispatch
    if __cli_command_exists $cmd
        if __cli_check_deps $cmd
            __cli_call_command $cmd $argv
        else
            return 1
        end
    else
        __cli_error "Unknown command: $cmd"
        echo "Run 'flo help' for usage information"
        return 1
    end
end
