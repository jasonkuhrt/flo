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

function __flo_validate_args --description "Validate function arguments" --argument-names expected_count actual_count function_name
    if test $actual_count -lt $expected_count
        __flo_error "$function_name: Expected at least $expected_count arguments, got $actual_count"
        return 1
    end
    return 0
end
