function __flo_remove_current_worktree --description "Remove current worktree safely"
    set -l current_worktree (__flo_get_current_worktree_name)
    if test -n "$current_worktree"
        # Navigate to main repo before removing
        cd (__flo_get_repo_root)
        flo rm $current_worktree
    end
end