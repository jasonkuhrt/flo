# Error handling utilities for flo

function __flo_error --description "Display error message and return failure" --argument-names message
    set_color red
    echo "flo: $message" >&2
    set_color normal
    return 1
end

function __flo_warn --description "Display warning message" --argument-names message
    set_color yellow
    echo "flo: $message" >&2
    set_color normal
end

function __flo_success --description "Display success message" --argument-names message
    set_color green
    echo "$message"
    set_color normal
end

function __flo_info --description "Display info message" --argument-names message
    set_color cyan
    echo "$message"
    set_color normal
end