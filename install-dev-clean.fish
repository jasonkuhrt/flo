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

# Clean out all existing flo files (simple pattern!)
echo "Cleaning out existing flo files..."
rm -f "$functions_dir"/__flo_*.fish
rm -f "$functions_dir"/flo.fish
rm -f "$completions_dir/flo.fish"

# Create symlinks for all main function files with __flo_ prefix
echo "Creating symlinks for all flo function files..."
for file in "$script_dir/functions"/*.fish
    set -l basename (basename "$file")
    if test "$basename" = "flo.fish"
        # flo.fish stays as-is (main entry point)
        set -l abs_file (realpath "$file")
        echo "  Linking $basename..."
        ln -sf "$abs_file" "$functions_dir/$basename"
    else
        # All other files get __flo_ prefix
        set -l new_name "__flo_$basename"
        set -l abs_file (realpath "$file")
        echo "  Linking $basename as $new_name..."
        ln -sf "$abs_file" "$functions_dir/$new_name"
    end
end

# Create symlinks for all helper files (already have __flo_ prefix)
echo "Creating symlinks for all helper files..."
for file in "$script_dir/functions/helpers"/*.fish
    set -l basename (basename "$file")
    set -l abs_file (realpath "$file")
    echo "  Linking $basename..."
    ln -sf "$abs_file" "$functions_dir/$basename"
end

# Create symlink for flo completions
echo "Creating symlink for flo completions..."
ln -sf (realpath "$script_dir/completions/flo.fish") "$completions_dir/flo.fish"

# Success message
echo ""
set_color green
echo "✓ Development installation complete!"
set_color normal
echo ""
echo "The following symlinks were created:"
echo "  $functions_dir/flo.fish → ./functions/flo.fish"
echo "  $functions_dir/__flo_*.fish → ./functions/*.fish"
echo "  $completions_dir/flo.fish → ./completions/flo.fish"
echo ""
echo "Any changes you make to files in the repo will immediately be reflected in your system."
echo ""
echo "To use flo, restart your Fish shell or run:"
echo "  source ~/.config/fish/config.fish"
