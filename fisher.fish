# Fisher plugin configuration for flo

# This file is sourced by Fisher when installing/uninstalling the plugin
# It defines hooks and configuration for the Fisher package manager

function __flo_fisher_install --on-event flo_install
    # Fisher install hook - runs when 'fisher install jasonkuhrt/flo' is executed

    # Check if required dependencies are available
    set -l missing_deps
    for dep in git gh
        if not command -q $dep
            set -a missing_deps $dep
        end
    end

    if test (count $missing_deps) -gt 0
        echo "⚠️  flo requires the following dependencies: $missing_deps"
        echo "Please install them before using flo."
        echo ""
        echo "Installation instructions:"
        for dep in $missing_deps
            switch $dep
                case git
                    echo "  • git: https://git-scm.com/downloads"
                case gh
                    echo "  • gh: https://cli.github.com"
            end
        end
        echo ""
    end

    # Check for optional dependencies
    set -l optional_deps gum jq fd rg bat delta
    set -l missing_optional
    for dep in $optional_deps
        if not command -q $dep
            set -a missing_optional $dep
        end
    end

    if test (count $missing_optional) -gt 0
        echo "📦 Optional dependencies not installed: $missing_optional"
        echo "Install them for the best flo experience:"
        echo "  brew install gum jq fd ripgrep bat git-delta"
        echo ""
    end

    # Success message
    echo "✅ flo installed successfully!"
    echo "Run 'flo help' to get started."
end

function __flo_fisher_update --on-event flo_update
    # Fisher update hook - runs when 'fisher update jasonkuhrt/flo' is executed
    echo "🔄 flo updated successfully!"
    echo "Run 'flo version' to see the current version."
end

function __flo_fisher_uninstall --on-event flo_uninstall
    # Fisher uninstall hook - runs when 'fisher remove jasonkuhrt/flo' is executed

    # Clean up any global variables or configurations
    set -e __cli_name
    set -e __cli_prefix
    set -e __cli_dir
    set -e __cli_description
    set -e __cli_version

    # Remove any cached data
    if test -d ~/.cache/flo
        rm -rf ~/.cache/flo
    end

    echo "👋 flo uninstalled successfully!"
end
