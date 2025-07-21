function __flo_reload --description "Reload flo by re-sourcing the main entry point"
    # Simply re-source the main flo function which will reload everything
    if test -f $__fish_config_dir/functions/flo.fish
        source $__fish_config_dir/functions/flo.fish
        echo "Reloaded flo functions"
    else
        echo "Error: Cannot find flo.fish in Fish functions directory"
        return 1
    end
end
