function flo_rm
    # Calculate worktree path from branch name
    set current_dir (basename (pwd))
    set sanitized_branch (string replace -a '/' '-' $argv[1])
    set worktree_path "../$current_dir"_"$sanitized_branch"

    # Remove worktree if it exists
    if test -d $worktree_path
        git worktree remove $worktree_path
        echo "✓ Removed worktree: $worktree_path"
    else
        echo "✗ Worktree not found: $worktree_path"
        echo "Tip: Run 'flo list' to see all worktrees"
    end
end
