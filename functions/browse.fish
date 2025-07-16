# Browse and list commands

function flo-list --description "List issues, PRs, or worktrees"
    set -l target $argv[1]
    
    switch $target
        case issues
            __flo_list_issues $argv[2..-1]
        case prs
            __flo_list_prs $argv[2..-1]
        case worktrees
            flo worktree list
        case '*'
            echo "Usage: flo list <issues|prs|worktrees>"
            return 1
    end
end

function __flo_list_issues
    if not __flo_check_gh_auth
        return 1
    end
    
    set -l limit 20
    set -l state "open"
    
    # Parse arguments
    for arg in $argv
        switch $arg
            case --all
                set state "all"
            case --closed
                set state "closed"
            case --limit=\*
                set limit (string split -m 1 = $arg)[2]
        end
    end
    
    echo "Fetching $state issues..."
    gh issue list --state $state --limit $limit
end

function __flo_list_prs
    if not __flo_check_gh_auth
        return 1
    end
    
    set -l limit 20
    set -l state "open"
    
    # Parse arguments
    for arg in $argv
        switch $arg
            case --all
                set state "all"
            case --closed --merged
                set state "closed"
            case --limit=\*
                set limit (string split -m 1 = $arg)[2]
        end
    end
    
    echo "Fetching $state PRs..."
    gh pr list --state $state --limit $limit
end

function flo-status --description "Show current worktree and PR status"
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

function flo-projects --description "List GitHub projects"
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