function __flo_error --description "Display error message and return failure" --argument-names message
    set_color red
    echo "flo: $message" >&2
    set_color normal
    return 1
end
