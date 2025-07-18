function __flo_parse_github_json --description "Parse GitHub JSON responses with error handling"
    set -l json_data $argv[1]
    set -l query $argv[2]

    # Check if jq is available
    if not command -q jq
        __flo_error "jq is required for JSON parsing. Please install jq."
        return 1
    end

    # Check if we have valid JSON data
    if test -z "$json_data"
        __flo_error "No JSON data provided"
        return 1
    end

    # Parse the JSON
    set -l result (echo $json_data | jq -r "$query" 2>/dev/null)

    if test $status -ne 0
        __flo_error "Failed to parse JSON data"
        return 1
    end

    echo $result
end
