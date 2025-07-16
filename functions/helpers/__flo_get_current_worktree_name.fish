function __flo_get_current_worktree_name --description "Get current worktree name if in flo worktree"
    set -l current_path (pwd)
    
    # Check if we're in a git worktree (not the main repo)
    set -l worktree_root (git rev-parse --show-toplevel 2>/dev/null)
    set -l git_dir (git rev-parse --git-dir 2>/dev/null)
    
    if test -n "$worktree_root" -a -n "$git_dir"
        # Check if this is a worktree (git-dir contains worktrees/)
        if string match -q "*/worktrees/*" $git_dir
            basename $worktree_root
        end
    end
end