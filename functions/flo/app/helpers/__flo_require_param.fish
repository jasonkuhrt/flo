function __flo_require_param --description "Validate that a required parameter is provided"
    set -l param_name $argv[1]
    set -l param_value $argv[2]
    set -l usage_message $argv[3]

    if test -z "$param_value"
        __flo_error "$param_name is required"
        if test -n "$usage_message"
            echo "$usage_message" >&2
        end
        return 1
    end

    return 0
end
