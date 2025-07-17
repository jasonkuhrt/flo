function __flo_remove_current_worktree --description "Remove current worktree safely"
    set -l current_worktree (__flo_get_current_worktree_name)
    if test -n "$current_worktree"
        # Use flo rm to remove just the worktree (default behavior)
        # Use --force to skip confirmation since this is called from automated workflow
        flo rm --force
    end
end
