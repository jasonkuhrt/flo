# Tab completions for flo commands

# Main flo command
complete -c flo -f -n __fish_use_subcommand -a issue -d "Start work on a GitHub issue"
complete -c flo -f -n __fish_use_subcommand -a issue-create -d "Create a new issue and start working on it"
complete -c flo -f -n __fish_use_subcommand -a pr -d "Create or manage pull requests"
complete -c flo -f -n __fish_use_subcommand -a worktree -d "Manage git worktrees"
complete -c flo -f -n __fish_use_subcommand -a list -d "List issues, PRs, or worktrees"
complete -c flo -f -n __fish_use_subcommand -a status -d "Show current worktree and PR status"
complete -c flo -f -n __fish_use_subcommand -a projects -d "List GitHub projects"
complete -c flo -f -n __fish_use_subcommand -a claude -d "Add current branch context to Claude"
complete -c flo -f -n __fish_use_subcommand -a claude-clean -d "Remove old Claude context files"

# flo worktree subcommands
complete -c flo -f -n "__fish_seen_subcommand_from worktree; and not __fish_seen_subcommand_from create delete remove list switch" -a create -d "Create a new worktree"
complete -c flo -f -n "__fish_seen_subcommand_from worktree; and not __fish_seen_subcommand_from create delete remove list switch" -a delete -d "Delete a worktree"
complete -c flo -f -n "__fish_seen_subcommand_from worktree; and not __fish_seen_subcommand_from create delete remove list switch" -a remove -d "Delete a worktree"
complete -c flo -f -n "__fish_seen_subcommand_from worktree; and not __fish_seen_subcommand_from create delete remove list switch" -a list -d "List all worktrees"
complete -c flo -f -n "__fish_seen_subcommand_from worktree; and not __fish_seen_subcommand_from create delete remove list switch" -a switch -d "Switch to a worktree"

# flo pr subcommands
complete -c flo -f -n "__fish_seen_subcommand_from pr; and not __fish_seen_subcommand_from create push checks merge" -a create -d "Create a pull request"
complete -c flo -f -n "__fish_seen_subcommand_from pr; and not __fish_seen_subcommand_from create push checks merge" -a push -d "Push current branch"
complete -c flo -f -n "__fish_seen_subcommand_from pr; and not __fish_seen_subcommand_from create push checks merge" -a checks -d "Show PR check status"
complete -c flo -f -n "__fish_seen_subcommand_from pr; and not __fish_seen_subcommand_from create push checks merge" -a merge -d "Merge the current PR"

# flo list subcommands
complete -c flo -f -n "__fish_seen_subcommand_from list; and not __fish_seen_subcommand_from issues prs worktrees" -a issues -d "List GitHub issues"
complete -c flo -f -n "__fish_seen_subcommand_from list; and not __fish_seen_subcommand_from issues prs worktrees" -a prs -d "List pull requests"
complete -c flo -f -n "__fish_seen_subcommand_from list; and not __fish_seen_subcommand_from issues prs worktrees" -a worktrees -d "List git worktrees"

# Dynamic completions for worktree names
function __flo_complete_worktrees --description "Complete worktree names for tab completion"
    git worktree list 2>/dev/null | awk '{
        # Extract branch name from the path
        split($1, parts, "/")
        branch = parts[length(parts)]
        # Skip if this is the main worktree
        if (branch != "main" && branch != "master") {
            print branch
        }
    }'
end

# Use dynamic completions for worktree delete/switch
complete -c flo -f -n "__fish_seen_subcommand_from worktree; and __fish_seen_subcommand_from delete remove switch" -a "(__flo_complete_worktrees)"

# Dynamic completions for issue numbers
function __flo_complete_issues --description "Complete issue numbers and titles for tab completion"
    if not gh auth status >/dev/null 2>&1
        return 1
    end

    # Simple caching - use a cache file with timestamp
    set -l cache_file "$HOME/.cache/flo/issues_complete"
    set -l cache_age_minutes 5

    # Create cache directory if it doesn't exist
    mkdir -p (dirname $cache_file)

    # Check if cache exists and is fresh
    if test -f $cache_file
        set -l cache_time (stat -f "%m" $cache_file 2>/dev/null; or echo 0)
        set -l current_time (date +%s)
        set -l age_minutes (math "($current_time - $cache_time) / 60")

        if test $age_minutes -lt $cache_age_minutes
            cat $cache_file
            return
        end
    end

    # Fetch fresh data and cache it
    gh issue list --limit 20 --json number,title 2>/dev/null | jq -r '.[] | "\(.number)\t\(.title)"' >$cache_file
    cat $cache_file
end

# Use dynamic completions for flo issue
complete -c flo -f -n "__fish_seen_subcommand_from issue" -a "(__flo_complete_issues)"

# Options for flo list commands
complete -c flo -f -n "__fish_seen_subcommand_from list; and __fish_seen_subcommand_from issues prs" -l all -d "Show all items (open and closed)"
complete -c flo -f -n "__fish_seen_subcommand_from list; and __fish_seen_subcommand_from issues prs" -l closed -d "Show only closed items"
complete -c flo -f -n "__fish_seen_subcommand_from list; and __fish_seen_subcommand_from issues prs" -l limit -d "Limit number of results"
