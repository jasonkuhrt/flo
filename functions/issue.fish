function issue --description "Start work on a GitHub issue"
    argparse --name="flo issue" h/help z/zed c/claude -- $argv; or return

    if set -q _flag_help
        __flo_show_help \
            --usage "flo issue <issue-number|issue-title>" \
            --description "Start work on a GitHub issue by creating a worktree and branch." \
            --args "issue-number|issue-title    GitHub issue number or search term" \
            --options "-h, --help    Show this help message
-z, --zed     Open worktree in Zed editor
-c, --claude  Generate Claude context after creation" \
            --examples "flo issue 123
flo issue \"Fix bug in parser\"
flo issue 123 --zed --claude"
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

        set title (__flo_parse_github_json "$issue_data" ".title"); or return
    else
        # Search for issue by title
        echo "Searching for issues matching: $issue_ref"
        set -l search_results (gh issue list --search "$issue_ref" --json number,title --limit 30)

        if test (__flo_parse_github_json "$search_results" ". | length") -eq 0
            echo "No issues found matching: $issue_ref"
            return 1
        end

        set -l result_count (__flo_parse_github_json "$search_results" ". | length")

        # Always use filter for text search results
        echo "Found $result_count issues:"
        set -l formatted_results (__flo_parse_github_json "$search_results" '.[] | "#\(.number) - \(.title)"')
        set -l selected (echo $formatted_results | gum filter \
            --placeholder "Type to refine search..." \
            --header "Filter $result_count results for: $issue_ref" \
            --height 15)

        if test -z "$selected"
            echo "No issue selected"
            return 1
        end

        # Extract issue number from selection
        set issue_number (echo $selected | sed 's/^#\([0-9]*\).*/\1/')
        set title (__flo_parse_github_json "$search_results" ".[] | select(.number == $issue_number) | .title")
    end

    # Generate branch name
    set -l branch_name "$issue_number-"(__flo_extract_branch_name $title)
    echo "Creating branch: $branch_name"

    # Create worktree for the issue with progress indicator
    gum spin --spinner dots --title "Creating worktree for issue #$issue_number..." -- __flo_create_worktree $branch_name
end
