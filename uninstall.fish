#!/usr/bin/env fish

# Flo uninstallation script

set -l script_dir (dirname (status --current-filename))

# Source the uninstall helper
source "$script_dir/functions/helpers/__flo_uninstall.fish"

# Run the uninstallation
__flo_uninstall
