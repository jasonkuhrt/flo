function __flo_gum_spin --description "Execute command with gum spinner"
    # Parse arguments
    argparse --name="__flo_gum_spin" \
        't/title=' \
        's/spinner=' \
        -- $argv; or return

    # Default values
    set -l title $_flag_title
    set -l spinner $_flag_spinner

    if test -z "$title"
        set title "Working..."
    end

    if test -z "$spinner"
        set spinner dots
    end

    # Remaining arguments are the command to execute
    if test (count $argv) -eq 0
        __flo_error "No command provided to __flo_gum_spin"
        return 1
    end

    # Execute with gum spin
    gum spin --spinner $spinner --title "$title" -- $argv
end
