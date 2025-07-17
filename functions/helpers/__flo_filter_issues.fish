function __flo_filter_issues --description "Let user fuzzy search and select from open issues"
    if not __flo_check_gh_auth
        return 1
    end

    # Use gh's Go template for better performance
    set -l formatted_issues (gh issue list --limit 50 --template '{{range .}}#{{.number}} - {{.title}}{{"\n"}}{{end}}' 2>/dev/null)

    if test -z "$formatted_issues"
        echo "No open issues found" >&2
        return 1
    end

    # Use gum filter for fuzzy search
    set -l selected (echo -n $formatted_issues | gum filter --placeholder "Type to filter issues..." --header "Search issues:")

    if test -z "$selected"
        echo "No issue selected" >&2
        return 1
    end

    # Extract the issue number from the selection
    set -l issue_number (echo $selected | sed 's/^#\([0-9]*\).*/\1/')

    echo $issue_number
end
