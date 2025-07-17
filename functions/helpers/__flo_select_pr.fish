function __flo_select_pr --description "Let user select from open PRs"
    if not __flo_check_gh_auth
        return 1
    end

    # Get PR count to decide between choose and filter
    set -l pr_count (gh pr list --limit 200 --json number --jq 'length' 2>/dev/null)

    if test -z "$pr_count" -o "$pr_count" -eq 0
        echo "No open pull requests found" >&2
        return 1
    end

    # Use filter for more than 8 PRs, choose for smaller lists
    if test $pr_count -gt 8
        # Use gh's Go template for all PRs (up to 200)
        set -l formatted_prs (gh pr list --limit 200 --template '{{range .}}#{{.number}} - {{.title}} ({{.headRefName}}){{"\n"}}{{end}}' 2>/dev/null)

        # Use gum filter for fuzzy search
        set -l selected (echo -n $formatted_prs | gum filter \
            --placeholder "Type to filter $pr_count PRs..." \
            --header "Search pull requests:" \
            --height 15)
    else
        # Use gh's Go template for small number of PRs
        set -l formatted_prs (gh pr list --limit 20 --template '{{range .}}#{{.number}} - {{.title}} ({{.headRefName}}){{"\n"}}{{end}}' 2>/dev/null)

        # Use gum choose for small lists
        set -l selected (echo -n $formatted_prs | gum choose --header "Select a PR:" --show-help)
    end

    if test -z "$selected"
        echo "No PR selected" >&2
        return 1
    end

    # Extract the PR number from the selection
    set -l pr_number (echo $selected | sed 's/^#\([0-9]*\).*/\1/')

    echo $pr_number
end
