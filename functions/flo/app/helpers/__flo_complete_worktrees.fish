function __flo_complete_worktrees --description "Complete worktree names for tab completion"
    git worktree list $FLO_STDERR_NULL | awk '{
        # Extract branch name from the path
        split($1, parts, "/")
        branch = parts[length(parts)]
        # Skip if this is the main worktree
        if (branch != "'$FLO_MAIN_BRANCH'" && branch != "'$FLO_FALLBACK_BRANCH'") {
            print branch
        }
    }'
end
