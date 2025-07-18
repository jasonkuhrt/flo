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
