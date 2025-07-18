function __flo_uninstall --description "Uninstall all flo files from the system"
    argparse --name="__flo_uninstall" q/quiet -- $argv; or return

    set -l fish_config_dir $__fish_config_dir
    set -l functions_dir "$fish_config_dir/functions"
    set -l completions_dir "$fish_config_dir/completions"

    if not set -q _flag_quiet
        echo "Uninstalling Flo..."
    end

    # Remove all flo-related function files and symlinks
    if not set -q _flag_quiet
        echo "Removing flo functions..."
    end
    set -l removed_count 0

    # Remove main flo files - use find to properly match patterns
    set -l flo_files (find "$functions_dir" -maxdepth 1 \( -name "__flo_*.fish" -o -name "flo*.fish" \) 2>/dev/null)
    for file in $flo_files
        rm -f "$file"
        set removed_count (math $removed_count + 1)
    end

    # Remove module files that might have been linked
    set -l modules issue pr next claude help helpers completions diff flo_rm
    for module in $modules
        if test -e "$functions_dir/$module.fish"
            rm -f "$functions_dir/$module.fish"
            set removed_count (math $removed_count + 1)
        end
    end

    # Remove completion file
    if test -e "$completions_dir/flo.fish"
        if not set -q _flag_quiet
            echo "Removing flo completions..."
        end
        rm -f "$completions_dir/flo.fish"
    end

    # Clean up ALL broken symlinks in the functions directory
    if not set -q _flag_quiet
        echo "Cleaning up broken symlinks..."
    end
    set -l broken_links (find "$functions_dir" -type l ! -exec test -e {} \; -print 2>/dev/null)
    for link in $broken_links
        rm -f "$link"
        set removed_count (math $removed_count + 1)
    end

    # Clean up any Claude context files
    set -l claude_dir ~/Desktop
    if test -d "$claude_dir"
        set -l claude_files (find "$claude_dir" -name "CLAUDE_*.md" -o -name "*-claude-context.md" 2>/dev/null)
        if test (count $claude_files) -gt 0
            if not set -q _flag_quiet
                echo "Cleaning up Claude context files..."
            end
            for file in $claude_files
                rm -f "$file"
            end
        end
    end

    # Verify removal - only check for flo-specific files, not all files containing "flo"
    set -l remaining_files
    for file in "$functions_dir"/flo*.fish "$functions_dir"/__flo_*.fish
        if test -e "$file"
            set remaining_files $remaining_files $file
        end
    end

    if test (count $remaining_files) -eq 0
        if not set -q _flag_quiet
            echo ""
            if test $removed_count -gt 0
                gum style --foreground 2 "✓ Flo has been completely uninstalled ($removed_count files removed)"
            else
                gum style --foreground 3 "⚠ Flo was not installed or already removed"
            end
            echo ""
            echo "To remove flo from your current session, restart your Fish shell."
        end
        return 0
    else
        if not set -q _flag_quiet
            echo ""
            gum log --level warn "⚠ Some flo files may remain:"
            for file in $remaining_files
                echo "  $file"
            end
            echo ""
            echo "You may need to manually remove these files."
        end
        return 1
    end
end
