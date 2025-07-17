# Pull request management functions

function pr --description "Create or manage pull requests"
    set -l cmd $argv[1]

    # Check for help flag without subcommand
    if test -z "$cmd"; and begin
            contains -- --help $argv; or contains -- -h $argv
        end
        echo "Usage: flo pr [subcommand]"
        echo ""
        echo "Subcommands:"
        echo "  create       Create a new pull request"
        echo "  push         Push current branch to origin"
        echo "  checks       Check PR status and CI checks"
        echo "  merge        Merge the pull request"
        echo ""
        echo "Default: create (if no subcommand given)"
        echo ""
        echo "Examples:"
        echo "  flo pr                Create a new PR"
        echo "  flo pr push           Push branch to origin"
        echo "  flo pr checks         Check CI status"
        return 0
    end

    # Only set -e if we have a command
    if test -n "$cmd"
        set -e argv[1]
    end

    switch $cmd
        case --help -h help
            echo "Usage: flo pr [subcommand]"
            echo ""
            echo "Subcommands:"
            echo "  create       Create a new pull request"
            echo "  push         Push current branch to origin"
            echo "  checks       Check PR status and CI checks"
            echo "  merge        Merge the pull request"
            echo ""
            echo "Default: create (if no subcommand given)"
            echo ""
            echo "Examples:"
            echo "  flo pr                Create a new PR"
            echo "  flo pr push           Push branch to origin"
            echo "  flo pr checks         Check CI status"
            return 0
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
    # Check for help flag
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: flo pr create"
        echo ""
        echo "Create a pull request for the current branch."
        echo "Automatically detects issue number from branch name and includes issue details."
        echo ""
        echo "Requirements:"
        echo "  - Must be on a feature branch (not main/master)"
        echo "  - Must have commits to push"
        echo "  - GitHub CLI must be authenticated"
        return 0
    end

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
    # Check for help flag
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: flo pr push"
        echo ""
        echo "Push the current branch to origin."
        echo ""
        echo "This command will:"
        echo "  - Push the current branch to the remote 'origin'"
        echo "  - Set up tracking if not already configured"
        return 0
    end

    set -l current_branch (git branch --show-current)

    if test -z "$current_branch"
        echo "Not on a branch"
        return 1
    end

    echo "Pushing $current_branch to origin..."
    git push origin $current_branch
end

function __flo_pr_checks --description "Check the status of PR checks"
    # Check for help flag
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: flo pr checks"
        echo ""
        echo "Check the CI/CD status of the PR for the current branch."
        echo ""
        echo "Shows:"
        echo "  - PR status checks (CI/CD runs)"
        echo "  - Check names and their current state"
        echo "  - Links to failed checks"
        return 0
    end

    if not __flo_check_gh_auth
        return 1
    end

    # Get PR for current branch
    set -l pr_number (gh pr view --json number -q .number 2>/dev/null)

    if test -z "$pr_number"
        echo "No PR found for current branch"
        return 1
    end

    gum style --bold "PR #$pr_number Status Checks:"
    echo ""

    # Get check runs data and format as table
    set -l checks_json (gh api "repos/{owner}/{repo}/pulls/$pr_number" --jq '.head.sha' | \
        xargs -I {} gh api "repos/{owner}/{repo}/commits/{}/check-runs" --jq '.check_runs')

    if test -n "$checks_json"
        echo "$checks_json" | jq -r '"Check,Status,Conclusion,Duration\n" + (.[] | "\(.name),\(.status),\(.conclusion // "pending"),\(((.completed_at // now | fromdateiso8601) - (.started_at | fromdateiso8601)) / 60 | floor | tostring + " min")")' | gum table --print --widths 40,15,15,10

        # Show summary
        echo ""
        set -l total_checks (echo "$checks_json" | jq 'length')
        set -l completed_checks (echo "$checks_json" | jq '[.[] | select(.status == "completed")] | length')
        set -l failed_checks (echo "$checks_json" | jq '[.[] | select(.conclusion == "failure")] | length')

        if test $failed_checks -gt 0
            gum style --foreground 1 "⚠ $failed_checks checks failed"
        else if test $completed_checks -eq $total_checks
            gum style --foreground 2 "✓ All checks passed"
        else
            gum style --foreground 3 "⏳ Checks in progress: $completed_checks/$total_checks completed"
        end
    else
        echo "No status checks found for this PR"
    end
end

function __flo_pr_merge --description "Merge the current pull request"
    # Check for help flag
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: flo pr merge"
        echo ""
        echo "Merge the pull request for the current branch."
        echo ""
        echo "Requirements:"
        echo "  - PR must be approved"
        echo "  - All checks must pass"
        echo "  - No merge conflicts"
        echo ""
        echo "The merge will use the repository's default merge method."
        return 0
    end

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
