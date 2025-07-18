function __flo_gum_select_multi --description "Multi-select UI with gum choose"
    # Parse arguments
    argparse --name="__flo_gum_select_multi" \
        'h/header=' \
        'height=' \
        'limit=' \
        'selected=+' \
        no-limit \
        -- $argv; or return

    # Build gum choose command
    set -l gum_args

    if set -q _flag_header
        set -a gum_args --header "$_flag_header"
    end

    if set -q _flag_height
        set -a gum_args --height $_flag_height
    end

    if set -q _flag_limit
        set -a gum_args --limit $_flag_limit
    else if not set -q _flag_no_limit
        # Default to no limit (allow multiple selections)
        set -a gum_args --no-limit
    end

    # Pre-select items if specified
    if set -q _flag_selected
        for item in $_flag_selected
            set -a gum_args --selected "$item"
        end
    end

    # Remaining arguments are the choices
    if test (count $argv) -eq 0
        __flo_error "No choices provided to __flo_gum_select_multi"
        return 1
    end

    # Execute gum choose
    printf '%s\n' $argv | gum choose $gum_args
end
