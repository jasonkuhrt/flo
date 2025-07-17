function flo-issue --description "Start work on a GitHub issue"
    argparse --name="flo issue" h/help z/zed c/claude -- $argv; or return

    if set -q _flag_help
        echo "Usage: flo issue <issue-number|issue-title>"
        echo ""
        echo "Start work on a GitHub issue by creating a worktree and branch."
        echo ""
        echo "Options:"
        echo "  -h, --help    Show this help message"
        echo "  -z, --zed     Open worktree in Zed editor"
        echo "  -c, --claude  Generate Claude context after creation"
        echo ""
        echo "Examples:"
        echo "  flo issue 123"
        echo "  flo issue \"Fix bug in parser\""
        echo "  flo issue 123 --zed --claude"
        return 0
    end

    set -l issue_ref $argv[1]

    if test -z "$issue_ref"
        echo "Usage: flo issue <issue-number|issue-title>"
        echo "Examples:"
        echo "  flo issue 123"
        echo "  flo issue \"Fix bug in parser\""
        return 1
    end

    if not __flo_check_gh_auth
        return 1
    end

    set -l org_repo (__flo_get_org_repo); or return 1

    # Parse issue number if provided
    set -l issue_number (__flo_parse_issue_number $issue_ref)
    set -l title ""

    if test -n "$issue_number"
        # Fetch issue by number
        echo "Fetching issue #$issue_number..."
        set -l issue_data (gh issue view $issue_number --json number,title 2>/dev/null); or begin
            echo "Issue #$issue_number not found"
            return 1
        end

        set title (echo $issue_data | jq -r '.title')
    else
        # Search for issue by title
        echo "Searching for issues matching: $issue_ref"
        set -l search_results (gh issue list --search "$issue_ref" --json number,title --limit 10)

        if test (echo $search_results | jq '. | length') -eq 0
            echo "No issues found matching: $issue_ref"
            return 1
        end

        # If multiple results, let user choose
        if test (echo $search_results | jq '. | length') -gt 1
            echo "Multiple issues found:"
            echo $search_results | jq -r '.[] | "#\(.number) - \(.title)"' | nl -v 0
            read -P "Select issue number (0-9): " selection

            set issue_number (echo $search_results | jq -r ".[$selection].number")
            set title (echo $search_results | jq -r ".[$selection].title")
        else
            set issue_number (echo $search_results | jq -r '.[0].number')
            set title (echo $search_results | jq -r '.[0].title')
        end
    end

    # Generate branch name
    set -l branch_name "$issue_number-"(__flo_extract_branch_name $title)
    echo "Creating branch: $branch_name"

    # Create worktree for the issue
    flo create $branch_name
end
