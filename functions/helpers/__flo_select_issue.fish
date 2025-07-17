function __flo_select_issue --description "Let user select from open issues"
    if not __flo_check_gh_auth
        return 1
    end

    # Use gh's Go template instead of jq for better performance
    set -l formatted_issues (gh issue list --limit 20 --template '{{range .}}#{{.number}} - {{.title}}{{"\n"}}{{end}}' 2>/dev/null)

    if test -z "$formatted_issues"
        echo "No open issues found" >&2
        return 1
    end

    # Use gum to select an issue with help shown
    set -l selected (echo -n $formatted_issues | gum choose --header "Select an issue:" --show-help)

    if test -z "$selected"
        echo "No issue selected" >&2
        return 1
    end

    # Extract the issue number from the selection
    set -l issue_number (echo $selected | sed 's/^#\([0-9]*\).*/\1/')

    echo $issue_number
end
