function __flo_info --description "Display info message" --argument-names message
    # Use gum style for info messages (cyan)
    gum style --foreground 6 "$message"
end
