function __flo_error --description "Display error message and return failure" --argument-names message
    gum log --level error "flo: $message"
    return 1
end
