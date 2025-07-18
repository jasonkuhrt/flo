function __flo_select_issue --description "Let user select from open issues"
    argparse --name="__flo_select_issue" f/filter c/choose l/limit= -- $argv; or return

    if not __flo_check_gh_auth
        return 1
    end

    # Set default limit
    set -l limit 50
    if set -q _flag_limit
        set limit $_flag_limit
    end

    # Get issue count to decide between choose and filter (if not explicitly set)
    set -l use_filter 0
    if set -q _flag_filter
        set use_filter 1
    else if set -q _flag_choose
        set use_filter 0
    else
        # Auto-decide based on count
        set -l issue_count (gh issue list --limit 200 --json number --jq 'length' 2>/dev/null)
        if test "$issue_count" -gt 10
            set use_filter 1
        end
    end

    # Get formatted issues using gh template for better performance
    set -l formatted_issues (gh issue list --limit $limit --template '{{range .}}#{{.number}} - {{.title}}{{"\n"}}{{end}}' 2>/dev/null)

    if test -z "$formatted_issues"
        echo "No open issues found" >&2
        return 1
    end

    # Use appropriate UI based on decision
    if test $use_filter -eq 1
        # Use gum filter for fuzzy search
        set -l selected (echo -n $formatted_issues | gum filter \
            --placeholder "Type to filter issues..." \
            --header "Search issues:" \
            --height 15)
    else
        # Use gum choose for small lists
        set -l selected (echo -n $formatted_issues | gum choose \
            --header "Select an issue:" \
            --show-help)
    end

    if test -z "$selected"
        echo "No issue selected" >&2
        return 1
    end

    # Extract the issue number from the selection
    set -l issue_number (echo $selected | sed 's/^#\([0-9]*\).*/\1/')

    echo $issue_number
end
