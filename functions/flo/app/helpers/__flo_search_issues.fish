function __flo_search_issues --description "Search for GitHub issues by number or text"
    set -l issue_ref $argv[1]

    if test -z "$issue_ref"
        __flo_error "No issue reference provided"
        return 1
    end

    # Check if it's an issue number
    set -l issue_number (__flo_parse_issue_number $issue_ref)

    if test -n "$issue_number"
        # Direct issue number lookup
        echo "Fetching issue #$issue_number..."
        set -l issue_data (__flo_fetch_issue_details $issue_number number title)

        if test $status -ne 0
            __flo_error "Issue #$issue_number not found"
            return 1
        end

        # Return issue number and title
        echo $issue_number
        __flo_get_issue_field "$issue_data" title
        return 0
    else
        # Text search
        echo "Searching for issues matching: $issue_ref"
        set -l search_results (gh issue list --search "$issue_ref" --json number,title --limit 30)

        if test (__flo_parse_github_json "$search_results" ". | length") -eq 0
            __flo_error "No issues found matching: $issue_ref"
            return 1
        end

        set -l result_count (__flo_parse_github_json "$search_results" ". | length")

        # Use gum to select from results
        echo "Found $result_count issues:"
        set -l formatted_results (__flo_parse_github_json "$search_results" '.[] | "#\(.number) - \(.title)"')
        set -l selected (echo $formatted_results | gum filter \
            --placeholder "Type to refine search..." \
            --header "Filter $result_count results for: $issue_ref" \
            --height 15)

        if test -z "$selected"
            __flo_error "No issue selected"
            return 1
        end

        # Extract issue number from selection
        set -l selected_number (echo $selected | sed 's/^#\([0-9]*\).*/\1/')
        set -l selected_title (__flo_parse_github_json "$search_results" ".[] | select(.number == $selected_number) | .title")

        # Return issue number and title
        echo $selected_number
        echo $selected_title
        return 0
    end
end
