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

# Clean out all existing flo-related files
echo "Cleaning out existing flo files..."
rm -f "$functions_dir"/flo*.fish
rm -f "$functions_dir"/*flo*.fish
rm -f "$functions_dir"/__flo*.fish
rm -f "$functions_dir"/browse.fish
rm -f "$functions_dir"/claude.fish
rm -f "$functions_dir"/completions.fish
rm -f "$functions_dir"/errors.fish
rm -f "$functions_dir"/help.fish
rm -f "$functions_dir"/helpers.fish
rm -f "$functions_dir"/issue.fish
rm -f "$functions_dir"/loader.fish
rm -f "$functions_dir"/main.fish
rm -f "$functions_dir"/next.fish
rm -f "$functions_dir"/flo-issue.fish
rm -f "$functions_dir"/pr.fish
rm -f "$functions_dir"/worktree.fish
rm -f "$completions_dir/flo.fish"

# Create symlinks for all function files
echo "Creating symlinks for all flo function files..."
for file in "$script_dir/functions"/*.fish
    set -l basename (basename "$file")
    set -l abs_file (realpath "$file")
    echo "  Linking $basename..."
    ln -sf "$abs_file" "$functions_dir/$basename"
end

# Create symlinks for all helper files
echo "Creating symlinks for all helper files..."
for file in "$script_dir/functions/helpers"/*.fish
    set -l basename (basename "$file")
    set -l abs_file (realpath "$file")
    echo "  Linking $basename..."
    ln -sf "$abs_file" "$functions_dir/$basename"
end

echo "Creating symlink for flo completions..."
set -l abs_completions (realpath "$script_dir/completions/flo.fish")
ln -sf "$abs_completions" "$completions_dir/flo.fish"

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
