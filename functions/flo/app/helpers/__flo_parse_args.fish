function __flo_validate_required --description "Validate required parameters"
    set -l param_name $argv[1]
    set -l param_value $argv[2]
    set -l usage_hint $argv[3]

    if test -z "$param_value"
        if test -n "$usage_hint"
            __flo_error "$usage_hint"
        else
            __flo_error "Missing required parameter: $param_name"
        end
        return 1
    end

    return 0
end

# Common option groups that can be included
function __flo_common_opts_help --description "Standard help option"
    echo h/help
end

function __flo_common_opts_verbose --description "Standard verbose option"
    echo v/verbose
end

function __flo_common_opts_editor --description "Editor selection options"
    echo z/zed
    echo c/claude
end

function __flo_common_opts_pr --description "Pull request options"
    echo d/draft
    echo "t/title="
    echo "b/body="
    echo "base="
end
