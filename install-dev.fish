#!/usr/bin/env fish

# Flo development installation script - uses symlinks for live development

set -l script_dir (dirname (status --current-filename))
set -l fish_config_dir ~/.config/fish
set -l functions_dir "$fish_config_dir/functions"
set -l completions_dir "$fish_config_dir/completions"

echo "Installing Flo for development (symlinks)..."

# Create Fish config directories if they don't exist
mkdir -p "$functions_dir"
mkdir -p "$completions_dir"

# Remove existing files if they exist
if test -e "$functions_dir/flo.fish"
    echo "Removing existing flo function..."
    rm -f "$functions_dir/flo.fish"
end

if test -e "$completions_dir/flo.fish"
    echo "Removing existing flo completions..."
    rm -f "$completions_dir/flo.fish"
end

# Create symlinks
echo "Creating symlink for flo function..."
ln -sf "$script_dir/functions/flo.fish" "$functions_dir/flo.fish"

echo "Creating symlink for flo completions..."
ln -sf "$script_dir/completions/flo.fish" "$completions_dir/flo.fish"

# Verify symlinks
if test -L "$functions_dir/flo.fish" -a -L "$completions_dir/flo.fish"
    set_color green
    echo "✓ Development installation complete!"
    set_color normal
    echo ""
    echo "The following symlinks were created:"
    echo "  $functions_dir/flo.fish → $script_dir/functions/flo.fish"
    echo "  $completions_dir/flo.fish → $script_dir/completions/flo.fish"
    echo ""
    echo "Any changes you make to files in the repo will immediately be reflected in your system."
    echo ""
    echo "To use flo, restart your Fish shell or run:"
    echo "  source ~/.config/fish/config.fish"
else
    set_color red
    echo "✗ Failed to create symlinks"
    set_color normal
    exit 1
end