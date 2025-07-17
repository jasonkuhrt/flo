function __flo_select_issue --description "Let user select from open issues"
    if not __flo_check_gh_auth
        return 1
    end

    set -l issues (gh issue list --json number,title --limit 20 2>/dev/null)

    if test -z "$issues" -o "$issues" = "[]"
        echo "No open issues found" >&2
        return 1
    end

    # Use gum to select an issue
    set -l selected (echo $issues | jq -r '.[] | "#\(.number) - \(.title)"' | gum choose --header "Select an issue:")

    if test -z "$selected"
        echo "No issue selected" >&2
        return 1
    end

    # Extract the issue number from the selection
    set -l issue_number (echo $selected | sed 's/^#\([0-9]*\).*/\1/')

    echo $issue_number
end
