function __flo_fetch_issue_details --description "Fetch issue details from GitHub API"
    set -l issue_number $argv[1]
    set -l fields $argv[2..-1]

    # Validate issue number
    if not __flo_validate_issue_number $issue_number
        __flo_error "Invalid issue number: $issue_number"
        return 1
    end

    # Default fields if none specified
    if test (count $fields) -eq 0
        set fields number title state body url
    end

    # Build fields query
    set -l json_fields (string join "," $fields)

    # Fetch issue data
    set -l issue_data (gh issue view $issue_number --json $json_fields 2>/dev/null)
    if test $status -ne 0
        return 1
    end

    # Return the raw JSON - callers can parse what they need
    echo $issue_data
end

function __flo_get_issue_field --description "Extract a specific field from issue JSON data"
    set -l json_data $argv[1]
    set -l field $argv[2]

    __flo_parse_github_json "$json_data" ".$field"
end
