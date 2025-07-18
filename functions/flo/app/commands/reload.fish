function flo_reload --description "Reload all flo functions"
    argparse --name="flo reload" h/help -- $argv; or return

    if set -q _flag_help
        __flo_show_help \
            --usage "flo reload" \
            --description "Reload all flo functions and commands." \
            --examples "flo reload"
        return 0
    end

    # Use the CLI framework's reload function
    __cli_reload
end
