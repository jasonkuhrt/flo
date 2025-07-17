function __flo_reload --description "Reload all flo functions"
    # Source all flo-related functions
    for f in ~/.config/fish/functions/flo*.fish ~/.config/fish/functions/__flo*.fish
        if test -f $f
            source $f
        end
    end

    # Source helpers.fish which loads all helpers
    if test -f ~/.config/fish/functions/helpers.fish
        source ~/.config/fish/functions/helpers.fish
    end

    echo "✓ Reloaded all flo functions"
end
