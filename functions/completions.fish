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

# Use dynamic completions for worktree delete/switch
complete -c flo -f -n "__fish_seen_subcommand_from worktree; and __fish_seen_subcommand_from delete remove switch" -a "(__flo_complete_worktrees)"

# Use dynamic completions for flo issue
complete -c flo -f -n "__fish_seen_subcommand_from issue" -a "(__flo_complete_issues)"

# Options for flo list commands
complete -c flo -f -n "__fish_seen_subcommand_from list; and __fish_seen_subcommand_from issues prs" -l all -d "Show all items (open and closed)"
complete -c flo -f -n "__fish_seen_subcommand_from list; and __fish_seen_subcommand_from issues prs" -l closed -d "Show only closed items"
complete -c flo -f -n "__fish_seen_subcommand_from list; and __fish_seen_subcommand_from issues prs" -l limit -d "Limit number of results"
