#!/usr/bin/env fish

# Flo development installation script - uses symlinks for live development

set -l script_dir (dirname (status --current-filename))

# Set FLO_DIR so the helper can find the flo directory
set -x FLO_DIR "$script_dir"

# Source the install helper
source "$script_dir/functions/helpers/__flo_install.fish"

# Run the installation in symlink mode
__flo_install symlink
