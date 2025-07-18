function flo_issue --description "Start work on a GitHub issue"
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

    __flo_validate_required issue_ref "$issue_ref" "Usage: flo issue <issue-number|issue-title>"; or return

    if not __flo_check_gh_auth
        return 1
    end

    set -l org_repo (__flo_get_org_repo); or return 1

    # Search for issue and get details
    set -l search_result (__flo_search_issues $issue_ref); or return
    set -l issue_number $search_result[1]
    set -l title $search_result[2]

    # Generate branch name
    set -l branch_name (__flo_generate_branch_name $issue_number $title); or return
    echo "Creating branch: $branch_name"

    # Create worktree for the issue with progress indicator
    __flo_gum_spin --title "Creating worktree for issue #$issue_number..." -- __flo_create_worktree $branch_name
end
