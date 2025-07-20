#!/usr/bin/env fish

# Development install script for flo
# Mirrors Fisher's algorithm exactly but uses symlinks instead of copies

set -l script_dir (dirname (status --current-filename))
set -l project_root (dirname $script_dir)
set -l fish_config ~/.config/fish

echo "Installing flo for development (symlinks)..."

# Create Fish config directories if they don't exist
mkdir -p $fish_config/functions
mkdir -p $fish_config/completions

# Mirror Fisher's file discovery and installation logic

# 1. Install main function files from functions/ directory
for file in $project_root/functions/*.fish
    if test -f $file
        set -l basename (basename $file)
        echo "  $fish_config/functions/$basename → $file"
        ln -sf $file $fish_config/functions/$basename
    end
end

# 2. Install function subdirectories (like functions/flo/)
for dir in $project_root/functions/*/
    if test -d $dir
        set -l basename (basename $dir)
        echo "  $fish_config/functions/$basename/ → $dir"
        ln -sf $dir $fish_config/functions/$basename
    end
end

# 3. Install completions
for file in $project_root/completions/*.fish
    if test -f $file
        set -l basename (basename $file)
        echo "  $fish_config/completions/$basename → $file"
        ln -sf $file $fish_config/completions/$basename
    end
end

# 4. Install root-level .fish files (like fisher.fish)
for file in $project_root/*.fish
    if test -f $file
        set -l basename (basename $file)
        # Skip install.fish and other non-plugin files
        if not string match -q "install*.fish" $basename
            echo "  $fish_config/functions/$basename → $file"
            ln -sf $file $fish_config/functions/$basename
        end
    end
end

echo ""
echo "✅ Development installation complete!"
echo ""
echo "Any changes to files in the repo will immediately be reflected in your Fish shell."
echo "To switch back to Fisher: fisher install jasonkuhrt/flo"
