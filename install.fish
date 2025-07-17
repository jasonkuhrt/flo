#!/usr/bin/env fish

# Flo installation script

set -l script_dir (dirname (status --current-filename))

# Set FLO_DIR so the helper can find the flo directory
set -x FLO_DIR "$script_dir"

# Source the install helper
source "$script_dir/functions/helpers/__flo_install.fish"

# Run the installation in copy mode
__flo_install copy
