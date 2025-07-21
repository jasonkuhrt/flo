#!/usr/bin/env fish

# Development install script for flo
# 
# Fisher copies files even for local paths (tested), so we need this custom
# script to create symlinks for instant feedback during development.
# 
# This mirrors Fisher's discovery algorithm but uses symlinks instead of copies.

set -l script_dir (dirname (status --current-filename))
set -l project_root (dirname $script_dir)
set -l fish_config ~/.config/fish

echo "Flo development install (symlinks)"
echo ""
echo "This mirrors Fisher's installation algorithm but creates symlinks instead"
echo "of copies, allowing instant feedback when you edit source files."

# Create Fish config directories if they don't exist
mkdir -p $fish_config/functions
mkdir -p $fish_config/completions

# Clean up any existing Fisher installation first
echo ""
echo "Cleaning up any existing installation..."
rm -f $fish_config/functions/flo.fish
rm -rf $fish_config/functions/flo
rm -f $fish_config/completions/flo.fish

# Create the clean symlink structure
echo ""
echo "Creating symlinks:"

# 1. Main function file
set -l abs_main_file (realpath $project_root/functions/flo.fish)
echo "  $abs_main_file"
echo "  -> $fish_config/functions/flo.fish"
ln -sf $abs_main_file $fish_config/functions/flo.fish

# 2. Private function directory 
set -l abs_flo_dir (realpath $project_root/functions/flo)
echo "  $abs_flo_dir/"
echo "  -> $fish_config/functions/flo/"
ln -sf $abs_flo_dir $fish_config/functions/flo

# 3. Completions file
set -l abs_completions (realpath $project_root/completions/flo.fish)
echo "  $abs_completions"
echo "  -> $fish_config/completions/flo.fish"
ln -sf $abs_completions $fish_config/completions/flo.fish

# Note: fisher.fish hooks are not symlinked in dev mode
# They are only needed for Fisher installations

echo ""
echo "Development installation complete!"
echo ""
echo "Live-linked files:"
echo "  functions/flo.fish     - Main entry point"
echo "  functions/flo/         - All commands, helpers, and library code"
echo "  completions/flo.fish   - Tab completions"
echo ""
echo "Any changes to these files will immediately be reflected in your Fish shell."
echo "To switch to Fisher: make install"
