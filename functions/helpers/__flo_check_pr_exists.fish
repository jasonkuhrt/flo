function __flo_check_pr_exists --description "Check if a PR exists for a branch or issue"
    set -l search_term $argv[1]
    set -l search_type $argv[2] # Optional: "branch" or "issue"

    if test -z "$search_term"
        return 1
    end

    # Build search query based on type
    set -l search_query
    if test "$search_type" = issue
        # Search for PR by issue branch pattern
        set search_query "head:issue/$search_term"
    else if test "$search_type" = branch
        # Search for PR by exact branch name
        set search_query "head:$search_term"
    else
        # Auto-detect: if numeric, assume issue; otherwise branch
        if __flo_validate_issue_number $search_term
            set search_query "head:issue/$search_term"
        else
            set search_query "head:$search_term"
        end
    end

    # Search for open PRs
    set -l pr_data (gh pr list --state open --search "$search_query" --json number,url,title --limit 1 2>/dev/null)

    if test $status -ne 0
        return 1
    end

    # Check if we found any PRs
    if test (__flo_parse_github_json "$pr_data" ". | length") -eq 0
        return 1
    end

    # Return PR number
    __flo_parse_github_json "$pr_data" ".[0].number"
    return 0
end
