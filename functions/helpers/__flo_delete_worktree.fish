function __flo_delete_worktree --description "Delete a git worktree"
    set -l branch_name $argv[1]

    if test -z "$branch_name"
        echo "Error: Branch name required" >&2
        return 1
    end

    if not __flo_worktree_exists $branch_name
        echo "Worktree '$branch_name' does not exist" >&2
        return 1
    end

    # Remove the worktree
    git worktree remove $branch_name --force

    # Delete the branch if it exists
    git branch -D $branch_name 2>/dev/null

    return 0
end
