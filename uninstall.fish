#!/usr/bin/env fish

# Flo uninstallation script

set -l fish_config_dir ~/.config/fish
set -l functions_dir "$fish_config_dir/functions"
set -l completions_dir "$fish_config_dir/completions"

echo "Uninstalling Flo..."

# Remove function file
if test -e "$functions_dir/flo.fish"
    echo "Removing flo function..."
    rm -f "$functions_dir/flo.fish"
end

# Remove completions file
if test -e "$completions_dir/flo.fish"
    echo "Removing flo completions..."
    rm -f "$completions_dir/flo.fish"
end

gum style --foreground 2 "✓ Flo has been uninstalled"
echo ""
echo "To complete the removal, restart your Fish shell or run:"
echo "  source ~/.config/fish/config.fish"
