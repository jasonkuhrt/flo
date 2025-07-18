function __flo_reload --description "Reload all flo functions"
    # Source all flo-related functions
    for f in $__fish_config_dir/functions/flo*.fish $__fish_config_dir/functions/__flo*.fish
        if test -f $f
            source $f
        end
    end

    # Source helpers.fish which loads all helpers
    if test -f $__fish_config_dir/functions/helpers.fish
        source $__fish_config_dir/functions/helpers.fish
    end

    echo "✓ Reloaded all flo functions"
end
