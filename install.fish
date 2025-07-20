#!/usr/bin/env fish

# Flo installation script
# For the best experience, use Fisher instead: fisher install jasonkuhrt/flo

echo "📦 Manual installation of flo"
echo ""
echo "⚠️  We strongly recommend using Fisher for easier installation and updates:"
echo ""
echo "  fisher install jasonkuhrt/flo"
echo ""
echo "Fisher provides:"
echo "  • Automatic installation and file management"
echo "  • Easy updates with 'fisher update'"
echo "  • Clean uninstall with 'fisher remove jasonkuhrt/flo'"
echo "  • Better Fish shell integration"
echo ""
echo "If you don't have Fisher, install it first:"
echo "  https://github.com/jorgebucaran/fisher"
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

# Simple manual installation by copying files
set -l script_dir (dirname (status --current-filename))
set -l fish_config ~/.config/fish

echo "Installing flo (manual copy mode)..."

# Create Fish config directories if they don't exist
mkdir -p $fish_config/functions
mkdir -p $fish_config/completions

# Copy main function files
for file in $script_dir/functions/*.fish
    if test -f $file
        set -l basename (basename $file)
        echo "  Copying $basename"
        cp $file $fish_config/functions/$basename
    end
end

# Copy function subdirectories
for dir in $script_dir/functions/*/
    if test -d $dir
        set -l basename (basename $dir)
        echo "  Copying $basename/"
        cp -r $dir $fish_config/functions/$basename
    end
end

# Copy completions
for file in $script_dir/completions/*.fish
    if test -f $file
        set -l basename (basename $file)
        echo "  Copying $basename"
        cp $file $fish_config/completions/$basename
    end
end

# Copy fisher.fish if it exists
if test -f $script_dir/fisher.fish
    echo "  Copying fisher.fish"
    cp $script_dir/fisher.fish $fish_config/functions/fisher.fish
end

echo ""
echo "✅ Manual installation complete!"
echo ""
echo "Restart your Fish shell or run:"
echo "  source ~/.config/fish/config.fish"
echo ""
echo "To uninstall manually, delete the copied files from ~/.config/fish/"
