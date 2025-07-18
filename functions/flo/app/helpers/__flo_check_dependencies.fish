function __flo_check_dependencies --description "Check for required external dependencies"
    argparse --name="__flo_check_dependencies" \
        'command=+' \
        'optional=+' \
        quiet \
        -- $argv; or return

    set -l missing_deps
    set -l missing_optional
    set -l checked_deps

    # Default required dependencies for all flo commands
    set -l core_deps git gh

    # Add core deps if not explicitly checking specific commands
    if not set -q _flag_command
        set _flag_command $core_deps
    end

    # Check required dependencies
    for dep in $_flag_command
        set -a checked_deps $dep
        if not command -q $dep
            set -a missing_deps $dep
        end
    end

    # Check optional dependencies
    if set -q _flag_optional
        for dep in $_flag_optional
            set -a checked_deps $dep
            if not command -q $dep
                set -a missing_optional $dep
            end
        end
    end

    # Report results
    if test (count $missing_deps) -gt 0
        if not set -q _flag_quiet
            __flo_error "Missing required dependencies: $missing_deps"
            echo ""
            echo "Please install the missing dependencies:"
            for dep in $missing_deps
                switch $dep
                    case git
                        echo "  - git: Version control system"
                        echo "    Install: https://git-scm.com/downloads"
                    case gh
                        echo "  - gh: GitHub CLI"
                        echo "    Install: brew install gh (macOS) or https://cli.github.com"
                    case gum
                        echo "  - gum: Interactive UI components"
                        echo "    Install: brew install gum (macOS) or https://github.com/charmbracelet/gum"
                    case jq
                        echo "  - jq: JSON processor"
                        echo "    Install: brew install jq (macOS) or https://jqlang.github.io/jq/download/"
                    case fd
                        echo "  - fd: Fast file finder"
                        echo "    Install: brew install fd (macOS) or https://github.com/sharkdp/fd"
                    case rg
                        echo "  - rg: Ripgrep for fast searching"
                        echo "    Install: brew install ripgrep (macOS) or https://github.com/BurntSushi/ripgrep"
                    case delta
                        echo "  - delta: Syntax-highlighted diff viewer"
                        echo "    Install: brew install git-delta (macOS) or https://github.com/dandavison/delta"
                    case bat
                        echo "  - bat: Syntax-highlighted file viewer"
                        echo "    Install: brew install bat (macOS) or https://github.com/sharkdp/bat"
                    case '*'
                        echo "  - $dep: Required dependency"
                end
            end
        end
        return 1
    end

    # Report optional dependencies if not quiet
    if test (count $missing_optional) -gt 0 -a not set -q _flag_quiet
        __flo_info "Optional dependencies not installed: $missing_optional"
        echo "Some features may be limited without these tools."
    end

    return 0
end

function __flo_has_command --description "Check if a command is available (for optional features)"
    command -q $argv[1]
end

function __flo_check_command_deps --description "Check dependencies for a specific flo command"
    set -l cmd $argv[1]
    set -l quiet_flag ""

    if test "$argv[2]" = --quiet
        set quiet_flag --quiet
    end

    switch $cmd
        case issue next
            __flo_check_dependencies --command gum jq --optional fd bat delta $quiet_flag
        case pr
            __flo_check_dependencies --command gum --optional delta $quiet_flag
        case claude
            __flo_check_dependencies --optional fd delta code $quiet_flag
        case flo_rm rm
            __flo_check_dependencies --command gum --optional delta $quiet_flag
        case '*'
            # For unknown commands, just check core dependencies
            __flo_check_dependencies $quiet_flag
    end
end
