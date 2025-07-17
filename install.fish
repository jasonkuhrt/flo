#!/usr/bin/env fish

# Flo installation script

set -l script_dir (dirname (status --current-filename))
set -l fish_config_dir ~/.config/fish
set -l functions_dir "$fish_config_dir/functions"
set -l completions_dir "$fish_config_dir/completions"

echo "Installing Flo..."

# Create Fish config directories if they don't exist
mkdir -p "$functions_dir"
mkdir -p "$completions_dir"

# Copy all function files
echo "Installing flo functions..."
cp "$script_dir/functions/"*.fish "$functions_dir/"

# Copy completions file
echo "Installing flo completions..."
cp "$script_dir/completions/flo.fish" "$completions_dir/"

echo "Installation complete!"
echo ""
echo "To use flo, restart your Fish shell or run:"
echo "  source ~/.config/fish/config.fish"
echo ""
echo "Then try:"
echo "  flo --help"
