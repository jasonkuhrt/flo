function __flo_select_issue --description "Let user select from open issues"
    if not __flo_check_gh_auth
        return 1
    end

    # Get issue count to decide between choose and filter
    set -l issue_count (gh issue list --limit 200 --json number --jq 'length' 2>/dev/null)

    if test -z "$issue_count" -o "$issue_count" -eq 0
        echo "No open issues found" >&2
        return 1
    end

    # Use filter for more than 10 issues, choose for smaller lists
    if test $issue_count -gt 10
        # Use gh's Go template for all issues (up to 200)
        set -l formatted_issues (gh issue list --limit 200 --template '{{range .}}#{{.number}} - {{.title}}{{"\n"}}{{end}}' 2>/dev/null)

        # Use gum filter for fuzzy search
        set -l selected (echo -n $formatted_issues | gum filter \
            --placeholder "Type to filter $issue_count issues..." \
            --header "Search issues:" \
            --height 15)
    else
        # Use gh's Go template for small number of issues
        set -l formatted_issues (gh issue list --limit 20 --template '{{range .}}#{{.number}} - {{.title}}{{"\n"}}{{end}}' 2>/dev/null)

        # Use gum choose for small lists
        set -l selected (echo -n $formatted_issues | gum choose --header "Select an issue:" --show-help)
    end

    if test -z "$selected"
        echo "No issue selected" >&2
        return 1
    end

    # Extract the issue number from the selection
    set -l issue_number (echo $selected | sed 's/^#\([0-9]*\).*/\1/')

    echo $issue_number
end
