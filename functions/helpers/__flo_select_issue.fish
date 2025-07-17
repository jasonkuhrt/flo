function __flo_select_issue --description "Let user select from open issues"
    if not __flo_check_gh_auth
        return 1
    end

    set -l issues (gh issue list --json number,title --limit 20 2>/dev/null)

    if test -z "$issues" -o "$issues" = "[]"
        echo "No open issues found" >&2
        return 1
    end

    # Use fzf to select an issue
    # Format: "number | title" and extract just the number after selection
    set -l selected (echo $issues | jq -r '.[] | "\(.number) | \(.title)"' | fzf --prompt="Select issue: " --header="Open Issues" --height=40% --reverse)

    if test -z "$selected"
        echo "No issue selected" >&2
        return 1
    end

    # Extract the issue number from the selection
    set -l issue_number (echo $selected | cut -d' ' -f1)

    echo $issue_number
end
