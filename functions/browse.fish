# Browse and list commands

function browse --description "List issues, PRs, or worktrees"
    set -l target $argv[1]

    # Check for help flag without a target
    if test -z "$target"; and begin
            contains -- --help $argv; or contains -- -h $argv
        end
        echo "Usage: flo list <target>"
        echo ""
        echo "List various GitHub and worktree items."
        echo ""
        echo "Targets:"
        echo "  issues      List GitHub issues"
        echo "  prs         List pull requests"
        echo "  worktrees   List git worktrees"
        echo ""
        echo "Examples:"
        echo "  flo list issues"
        echo "  flo list prs"
        echo "  flo list worktrees"
        return 0
    end

    switch $target
        case --help -h help
            echo "Usage: flo list <target>"
            echo ""
            echo "List various GitHub and worktree items."
            echo ""
            echo "Targets:"
            echo "  issues      List GitHub issues"
            echo "  prs         List pull requests"
            echo "  worktrees   List git worktrees"
            echo ""
            echo "Examples:"
            echo "  flo list issues"
            echo "  flo list prs"
            echo "  flo list worktrees"
            return 0
        case issues
            __flo_list_issues $argv[2..-1]
        case prs
            __flo_list_prs $argv[2..-1]
        case worktrees
            flo worktree list $argv[2..-1]
        case '*'
            echo "Usage: flo list <issues|prs|worktrees>"
            return 1
    end
end

function __flo_list_issues --description "List GitHub issues with optional filtering"
    if not __flo_check_gh_auth
        return 1
    end

    # Parse arguments with argparse
    argparse --name="flo list issues" all closed 'limit=' -- $argv; or return

    set -l limit 20
    set -l state open

    if set -q _flag_all
        set -l state all
    end
    if set -q _flag_closed
        set -l state closed
    end
    if set -q _flag_limit
        set -l limit $_flag_limit
    end

    echo "Fetching $state issues..."
    gh issue list --state $state --limit $limit
end

function __flo_list_prs --description "List GitHub pull requests with optional filtering"
    # Check for help flag
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: flo list prs [options]"
        echo ""
        echo "List pull requests for the current repository."
        echo ""
        echo "Options:"
        echo "  --all        Show all PRs (open, closed, merged)"
        echo "  --closed     Show only closed/merged PRs"
        echo "  --limit N    Limit number of PRs (default: 20)"
        echo ""
        echo "Examples:"
        echo "  flo list prs"
        echo "  flo list prs --closed"
        echo "  flo list prs --all --limit 50"
        return 0
    end

    if not __flo_check_gh_auth
        return 1
    end

    set -l limit 20
    set -l state open

    # Parse arguments
    for arg in $argv
        switch $arg
            case --all
                set -l state all
            case --closed --merged
                set -l state closed
            case --limit=\*
                set -l limit (string split -m 1 = $arg)[2]
        end
    end

    echo "Fetching $state PRs..."
    gh pr list --state $state --limit $limit
end

function flo_status --description "Show current worktree and PR status"
    # Current worktree info
    set -l current_branch (git branch --show-current 2>/dev/null)
    set -l current_worktree (pwd)

    if test -z "$current_branch"
        echo "Not in a git repository"
        return 1
    end

    echo "Current branch: $current_branch"
    echo "Worktree: $current_worktree"
    echo ""

    # Check for associated PR
    if __flo_check_gh_auth
        set -l pr_info (gh pr view --json number,title,state,url 2>/dev/null)

        if test $status -eq 0
            echo "Pull Request:"
            echo $pr_info | jq -r '"  #\(.number) - \(.title)"'
            echo $pr_info | jq -r '"  State: \(.state)"'
            echo $pr_info | jq -r '"  URL: \(.url)"'
        else
            echo "No pull request found for this branch"
        end
        echo ""
    end

    # Git status
    echo "Git status:"
    git status -s
end

function projects --description "List GitHub projects"
    if not __flo_check_gh_auth
        return 1
    end

    set -l org_repo (__flo_get_org_repo)
    if test $status -ne 0
        return 1
    end

    echo "Fetching projects for $org_repo..."
    gh project list --owner (string split / $org_repo)[1]
end
