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

    gum spin --spinner dots --title "Fetching $state issues..." -- gh issue list --state $state --limit $limit --json number,title,author,updatedAt,labels,milestone 2>/dev/null |
        jq -r '"Number,Title,Author,Updated,Labels\n" + (.[] | "#\(.number),\(.title),\(.author.login),\(((.updatedAt | fromdateiso8601) - (now | floor)) / 86400 | floor | tostring + " days ago"),\(.labels | map(.name) | join("; "))")' |
        gum table --print --widths 10,50,15,15,20
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

    gum spin --spinner dots --title "Fetching $state PRs..." -- gh pr list --state $state --limit $limit --json number,title,author,updatedAt,headRefName,isDraft,reviewDecision 2>/dev/null |
        jq -r '"Number,Title,Author,Branch,Status,Updated\n" + (.[] | "#\(.number),\(.title),\(.author.login),\(.headRefName),\(if .isDraft then "Draft" elif .reviewDecision == "APPROVED" then "Approved" elif .reviewDecision == "CHANGES_REQUESTED" then "Changes Requested" else "Pending" end),\(((.updatedAt | fromdateiso8601) - (now | floor)) / 86400 | floor | tostring + " days ago")")' |
        gum table --print --widths 10,40,15,20,18,15
end

function flo_status --description "Show current worktree and PR status"
    # Current worktree info
    set -l current_branch (git branch --show-current 2>/dev/null)
    set -l current_worktree (pwd)

    if test -z "$current_branch"
        echo "Not in a git repository"
        return 1
    end

    # Display basic info in a nice table
    echo -e "Branch,Worktree\n$current_branch,$current_worktree" | gum table --print
    echo ""

    # Check for associated PR
    if __flo_check_gh_auth
        set -l pr_info (gh pr view --json number,title,state,url,mergeable,reviews 2>/dev/null)

        if test $status -eq 0
            # Extract PR details
            set -l pr_number (echo $pr_info | jq -r '.number')
            set -l pr_title (echo $pr_info | jq -r '.title')
            set -l pr_state (echo $pr_info | jq -r '.state')
            set -l pr_url (echo $pr_info | jq -r '.url')
            set -l pr_mergeable (echo $pr_info | jq -r '.mergeable // "UNKNOWN"')
            set -l review_count (echo $pr_info | jq -r '.reviews | length')

            # Create PR details table
            echo "Field,Value" >/tmp/flo_pr_status.csv
            echo "PR Number,#$pr_number" >>/tmp/flo_pr_status.csv
            echo "Title,$pr_title" >>/tmp/flo_pr_status.csv
            echo "State,$pr_state" >>/tmp/flo_pr_status.csv
            echo "Mergeable,$pr_mergeable" >>/tmp/flo_pr_status.csv
            echo "Reviews,$review_count" >>/tmp/flo_pr_status.csv
            echo "URL,$pr_url" >>/tmp/flo_pr_status.csv

            cat /tmp/flo_pr_status.csv | gum table --print
            rm -f /tmp/flo_pr_status.csv
        else
            gum style --foreground 245 "No pull request found for this branch"
        end
        echo ""
    end

    # Git status summary
    set -l git_status (git status --porcelain 2>/dev/null)
    if test -n "$git_status"
        set -l modified_count (echo "$git_status" | grep -c '^.M')
        set -l added_count (echo "$git_status" | grep -c '^A')
        set -l deleted_count (echo "$git_status" | grep -c '^D')
        set -l untracked_count (echo "$git_status" | grep -c '^??')

        echo "Git Status Summary:" | gum style --bold
        echo -e "Type,Count\nModified,$modified_count\nAdded,$added_count\nDeleted,$deleted_count\nUntracked,$untracked_count" | gum table --print

        if test (count (echo "$git_status" | head -10)) -gt 0
            echo ""
            echo "Recent changes:" | gum style --italic
            git status -s | head -10
        end
    else
        gum style --foreground 2 "✓ Working directory clean"
    end
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
