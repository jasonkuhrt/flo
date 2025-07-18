function __flo_delete_worktree --description "Delete a git worktree"
    set -l branch_name $argv[1]

    __flo_require_param branch_name "$branch_name" "Usage: __flo_delete_worktree <branch-name>"; or return

    if not __flo_worktree_exists $branch_name
        __flo_error "Worktree '$branch_name' does not exist"
        return 1
    end

    # Remove the worktree
    git worktree remove $branch_name --force

    # Delete the branch if it exists
    git branch -D $branch_name 2>/dev/null

    return 0
end
