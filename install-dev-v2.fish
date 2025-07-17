#!/usr/bin/env fish

# Flo development installation script - uses symlinks for live development

set -l script_dir (dirname (status --current-filename))
set -l fish_config_dir ~/.config/fish
set -l functions_dir "$fish_config_dir/functions"
set -l completions_dir "$fish_config_dir/completions"
set -l flo_functions_dir "$functions_dir/flo"

echo "Installing Flo for development (symlinks)..."

# Create Fish config directories if they don't exist
mkdir -p "$functions_dir"
mkdir -p "$completions_dir"
mkdir -p "$flo_functions_dir"

# Clean out the entire flo subdirectory
echo "Cleaning out existing flo files..."
rm -rf "$flo_functions_dir"
mkdir -p "$flo_functions_dir"

# Remove old flo.fish from main functions dir
rm -f "$functions_dir/flo.fish"
rm -f "$completions_dir/flo.fish"

# Create symlinks for all function files in the flo subdirectory
echo "Creating symlinks for all flo function files..."
for file in "$script_dir/functions"/*.fish
    set -l basename (basename "$file")
    set -l abs_file (realpath "$file")
    echo "  Linking $basename..."
    ln -sf "$abs_file" "$flo_functions_dir/$basename"
end

# Create symlinks for all helper files in the flo subdirectory
echo "Creating symlinks for all helper files..."
for file in "$script_dir/functions/helpers"/*.fish
    set -l basename (basename "$file")
    set -l abs_file (realpath "$file")
    echo "  Linking $basename..."
    ln -sf "$abs_file" "$flo_functions_dir/$basename"
end

# Create the main flo.fish that sources the loader
echo "Creating main flo loader..."
set -l flo_main_content "# Auto-generated flo loader
source $flo_functions_dir/loader.fish"
echo "$flo_main_content" >"$functions_dir/flo.fish"

# Create symlink for flo completions
echo "Creating symlink for flo completions..."
ln -sf (realpath "$script_dir/completions/flo.fish") "$completions_dir/flo.fish"

# Success message
echo ""
set_color green
echo "✓ Development installation complete!"
set_color normal
echo ""
echo "The following were created:"
echo "  $functions_dir/flo.fish (loads flo from subdirectory)"
echo "  $flo_functions_dir/ (contains all flo functions)"
echo "  $completions_dir/flo.fish → ./completions/flo.fish"
echo ""
echo "Any changes you make to files in the repo will immediately be reflected in your system."
echo ""
echo "To use flo, restart your Fish shell or run:"
echo "  source ~/.config/fish/config.fish"
