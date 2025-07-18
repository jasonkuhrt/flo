#!/usr/bin/env fish

# Flo installation script

set -l script_dir (dirname (status --current-filename))

# Check if Fisher is available and suggest using it
if command -q fisher
    echo "🎣 Fisher detected! We recommend using Fisher for easier installation and updates:"
    echo ""
    echo "  fisher install jasonkuhrt/flo"
    echo ""
    echo "This will:"
    echo "  • Install flo automatically"
    echo "  • Enable easy updates with 'fisher update'"
    echo "  • Provide clean uninstall with 'fisher remove jasonkuhrt/flo'"
    echo ""

    # Ask user if they want to continue with manual install
    echo "Do you want to continue with manual installation instead? (y/N)"
    read -l response

    if test "$response" != y -a "$response" != Y
        echo "Installation cancelled. Use 'fisher install jasonkuhrt/flo' instead."
        exit 0
    end

    echo "Proceeding with manual installation..."
    echo ""
else
    echo "📦 Consider installing Fisher for easier package management:"
    echo "  https://github.com/jorgebucaran/fisher"
    echo ""
end

# Set FLO_DIR so the helper can find the flo directory
set -x FLO_DIR "$script_dir"

# Source the install helper
source "$script_dir/functions/flo/app/helpers/__flo_install.fish"

# Run the installation in copy mode
__flo_install copy
