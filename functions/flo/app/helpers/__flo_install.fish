function __flo_install --description "Install flo functions and completions"
    argparse --name="__flo_install" q/quiet -- $argv; or return

    set -l mode $argv[1] # "copy" or "symlink"
    if test -z "$mode"
        set mode copy
    end

    # Find the flo directory - handle being called from different contexts
    set -l flo_dir
    if test -n "$FLO_DIR"
        set flo_dir "$FLO_DIR"
    else if test -d (dirname (dirname (status --current-filename)))/functions
        set flo_dir (dirname (dirname (status --current-filename)))
    else if test -d ./functions
        set flo_dir (pwd)
    else
        echo "Error: Cannot find flo directory. Set FLO_DIR or run from flo repo."
        return 1
    end

    set -l fish_config_dir $__fish_config_dir
    set -l functions_dir "$fish_config_dir/functions"
    set -l completions_dir "$fish_config_dir/completions"

    if not set -q _flag_quiet
        echo "Installing Flo ($mode mode)..."
    end

    # Create Fish config directories if they don't exist
    mkdir -p "$functions_dir"
    mkdir -p "$completions_dir"

    # Clean existing installation first
    # Source the uninstall helper if not already available
    if not functions -q __flo_uninstall
        source "$flo_dir/functions/flo/app/helpers/__flo_uninstall.fish"
    end
    __flo_uninstall --quiet

    # Install based on mode
    if test "$mode" = symlink
        if not set -q _flag_quiet
            echo "Creating symlinks for flo..."
        end

        # Create symlink for main function file
        set -l abs_flo_file (realpath "$flo_dir/functions/flo.fish")
        ln -sf "$abs_flo_file" "$functions_dir/flo.fish"

        # Create symlink for the entire flo subdirectory structure
        set -l abs_flo_dir (realpath "$flo_dir/functions/flo")
        ln -sf "$abs_flo_dir" "$functions_dir/flo"

        # Create symlink for completions
        set -l abs_completions (realpath "$flo_dir/completions/flo.fish")
        ln -sf "$abs_completions" "$completions_dir/flo.fish"

        if not set -q _flag_quiet
            echo ""
            echo "The following symlinks were created:"
            echo "  $functions_dir/flo.fish → $flo_dir/functions/flo.fish"
            echo "  $functions_dir/flo/ → $flo_dir/functions/flo/"
            echo "  $completions_dir/flo.fish → $flo_dir/completions/flo.fish"
            echo ""
            echo "Any changes you make to files in the repo will immediately be reflected in your system."
        end

    else
        # Copy mode
        if not set -q _flag_quiet
            echo "Copying flo files..."
        end

        # Copy main function file
        cp "$flo_dir/functions/flo.fish" "$functions_dir/flo.fish"

        # Copy the entire flo subdirectory structure
        cp -r "$flo_dir/functions/flo" "$functions_dir/"

        # Copy completions
        cp "$flo_dir/completions/flo.fish" "$completions_dir/flo.fish"

        if not set -q _flag_quiet
            echo ""
            echo "Flo has been installed to:"
            echo "  $functions_dir/flo.fish"
            echo "  $functions_dir/flo/"
            echo "  $completions_dir/flo.fish"
        end
    end

    # Verify installation
    if test -e "$functions_dir/flo.fish" -a -e "$completions_dir/flo.fish"
        if not set -q _flag_quiet
            echo ""
            gum style --foreground 2 "✓ Installation complete!"
            echo ""
            echo "To use flo, restart your Fish shell or run:"
            echo "  source $fish_config_dir/config.fish"
        end
        return 0
    else
        if not set -q _flag_quiet
            gum log --level error "✗ Installation failed"
        end
        return 1
    end
end
