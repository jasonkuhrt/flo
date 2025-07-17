# Pull request management functions

function flo-pr --description "Create or manage pull requests"
    set -l cmd $argv[1]
    set -e argv[1]

    switch $cmd
        case create
            __flo_pr_create $argv
        case push
            __flo_pr_push $argv
        case checks
            __flo_pr_checks $argv
        case merge
            __flo_pr_merge $argv
        case '*'
            # Default to create if no subcommand
            __flo_pr_create $cmd $argv
    end
end

function __flo_pr_create --description "Create a new pull request"
    if not __flo_check_gh_auth
        return 1
    end

    # Check if we're in a git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Not in a git repository"
        return 1
    end

    # Get current branch
    set -l current_branch (git branch --show-current)

    if test "$current_branch" = main -o "$current_branch" = master
        echo "Cannot create PR from main/master branch"
        return 1
    end

    # Check if branch has commits
    set -l commits_ahead (git rev-list --count origin/main..$current_branch 2>/dev/null)
    if test -z "$commits_ahead" -o "$commits_ahead" = 0
        echo "No commits to create PR from"
        echo "Make some changes and commit them first"
        return 1
    end

    # Push branch if needed
    echo "Pushing branch to origin..."
    git push -u origin $current_branch

    if test $status -ne 0
        echo "Failed to push branch"
        return 1
    end

    # Extract issue number from branch name if it exists
    set -l issue_number (__flo_parse_issue_number $current_branch)

    # Create PR
    echo "Creating pull request..."

    if test -n "$issue_number"
        # Link to issue if we have one
        gh pr create --fill --head $current_branch --web
    else
        # Just create PR without issue link
        gh pr create --fill --head $current_branch --web
    end
end

function __flo_pr_push --description "Push current branch to origin"
    set -l current_branch (git branch --show-current)

    if test -z "$current_branch"
        echo "Not on a branch"
        return 1
    end

    echo "Pushing $current_branch to origin..."
    git push origin $current_branch
end

function __flo_pr_checks --description "Check the status of PR checks"
    if not __flo_check_gh_auth
        return 1
    end

    # Get PR for current branch
    set -l pr_number (gh pr view --json number -q .number 2>/dev/null)

    if test -z "$pr_number"
        echo "No PR found for current branch"
        return 1
    end

    echo "Checking PR #$pr_number status..."
    gh pr checks $pr_number
end

function __flo_pr_merge --description "Merge the current pull request"
    if not __flo_check_gh_auth
        return 1
    end

    # Get PR for current branch
    set -l pr_number (gh pr view --json number -q .number 2>/dev/null)

    if test -z "$pr_number"
        echo "No PR found for current branch"
        return 1
    end

    # Check if PR is ready to merge
    set -l pr_status (gh pr view $pr_number --json mergeable,reviews -q '{mergeable: .mergeable, reviews: .reviews}')

    echo "Merging PR #$pr_number..."
    gh pr merge $pr_number --squash --delete-branch

    if test $status -eq 0
        echo "PR merged successfully"
        # Switch back to main worktree
        set -l main_worktree (git worktree list | string match -r '.*\[(main|master)\]' | string split ' ' | head -1)
        if test -n "$main_worktree"
            cd $main_worktree
            git pull origin main
        end
    end
end
