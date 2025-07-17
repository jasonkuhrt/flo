function __flo_validate_args --description "Validate function arguments" --argument-names expected_count actual_count function_name
    if test $actual_count -lt $expected_count
        __flo_error "$function_name: Expected at least $expected_count arguments, got $actual_count"
        return 1
    end
    return 0
end
