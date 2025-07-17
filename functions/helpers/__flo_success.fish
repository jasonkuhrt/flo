function __flo_success --description "Display success message" --argument-names message
    # Use gum style for success messages (green with checkmark)
    gum style --foreground 2 "$message"
end
