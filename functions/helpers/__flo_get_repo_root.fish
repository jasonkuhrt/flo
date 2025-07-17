function __flo_get_repo_root --description "Get the root directory of the git repository"
    # Get the main repository root, not the worktree root
    set -l git_dir (git rev-parse --git-dir 2>/dev/null)
    if test -n "$git_dir"
        # If in a worktree, git-dir points to .git/worktrees/<name>
        if string match -q "*/worktrees/*" $git_dir
            # Extract main repo path from worktree git-dir
            set -l main_git_dir (string replace -r '/worktrees/[^/]+$' '' $git_dir)
            dirname $main_git_dir
        else
            # In main repo
            git rev-parse --show-toplevel 2>/dev/null
        end
    end
end
