# Tab completions for flo commands

# Main flo command
complete -c flo -f -n __fish_use_subcommand -a issue -d "Start work on a GitHub issue"
complete -c flo -f -n __fish_use_subcommand -a pr -d "Create pull request for current branch"
complete -c flo -f -n __fish_use_subcommand -a next -d "Start next issue (context-aware)"
complete -c flo -f -n __fish_use_subcommand -a rm -d "Remove issue, PR, and/or worktree"
complete -c flo -f -n __fish_use_subcommand -a claude -d "Add current branch context to Claude"
complete -c flo -f -n __fish_use_subcommand -a claude-clean -d "Remove old Claude context files"
complete -c flo -f -n __fish_use_subcommand -a help -d "Show help message"

# Use dynamic completions for flo issue
complete -c flo -f -n "__fish_seen_subcommand_from issue" -a "(__flo_complete_issues)"

# Options for specific commands
complete -c flo -f -n "__fish_seen_subcommand_from pr" -s t -l title -d "PR title"
complete -c flo -f -n "__fish_seen_subcommand_from pr" -s b -l body -d "PR body/description"
complete -c flo -f -n "__fish_seen_subcommand_from pr" -s d -l draft -d "Create as draft PR"
complete -c flo -f -n "__fish_seen_subcommand_from pr" -l base -d "Base branch"

complete -c flo -f -n "__fish_seen_subcommand_from rm" -l close-issue -d "Close the GitHub issue"
complete -c flo -f -n "__fish_seen_subcommand_from rm" -l close-pr -d "Close the pull request"
complete -c flo -f -n "__fish_seen_subcommand_from rm" -l no-delete-worktree -d "Don't delete the worktree"
complete -c flo -f -n "__fish_seen_subcommand_from rm" -s f -l force -d "Skip confirmation prompt"
