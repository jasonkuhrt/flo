# Dependency management for CLI framework

# Store dependency requirements for commands
set -g __cli_deps_registry

function __cli_register_deps --description "Register dependencies for a command"
    set -l cmd $argv[1]
    set -l deps $argv[2..-1]

    # Store in global variable
    set -g __cli_deps_$cmd $deps
end

function __cli_check_deps --description "Check dependencies for a command"
    set -l cmd $argv[1]
    set -l deps_var __cli_deps_$cmd

    # Check if command has registered dependencies
    if not set -q $deps_var
        # No dependencies registered
        return 0
    end

    # Get the dependencies
    set -l deps $$deps_var
    set -l missing

    # Check each dependency
    for dep in $deps
        if not command -q $dep
            set -a missing $dep
        end
    end

    # Report missing dependencies
    if test (count $missing) -gt 0
        __cli_error "Missing dependencies for '$cmd': $missing"
        echo ""
        echo "Please install the missing dependencies:"
        for dep in $missing
            __cli_show_dep_install_info $dep
        end
        return 1
    end

    return 0
end

function __cli_show_dep_install_info --description "Show installation info for a dependency"
    set -l dep $argv[1]

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
            echo "    Install: brew install jq (macOS) or https://jqlang.github.io/jq/"
        case fd
            echo "  - fd: Fast file finder"
            echo "    Install: brew install fd (macOS) or https://github.com/sharkdp/fd"
        case rg ripgrep
            echo "  - ripgrep: Fast text search"
            echo "    Install: brew install ripgrep (macOS) or https://github.com/BurntSushi/ripgrep"
        case '*'
            echo "  - $dep: Required dependency"
            echo "    Please check your package manager"
    end
end

# Convenience function to check deps before running a command
function __cli_with_deps --description "Run a command with dependency checking"
    set -l cmd $argv[1]
    set -e argv[1]

    if __cli_check_deps $cmd
        __cli_call_command $cmd $argv
    else
        return 1
    end
end
