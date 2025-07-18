function __flo_warn --description "Display warning message" --argument-names message
    gum log --level warn "flo: $message"
end
