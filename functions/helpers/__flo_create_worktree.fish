function __flo_create_worktree --description "Create a git worktree for a branch"
    set -l branch_name $argv[1]

    __flo_require_param branch_name "$branch_name" "Usage: __flo_create_worktree <branch-name>"; or return

    # Get the worktree location
    set -l location (__flo_get_worktree_location); or return

    set -l worktree_path "$location/$branch_name"

    # Check if worktree already exists
    if __flo_worktree_exists $branch_name
        __flo_error "Worktree '$branch_name' already exists"
        return 1
    end

    # Create the worktree
    if git worktree add -b "$branch_name" "$worktree_path"
        echo "Created worktree at: $worktree_path"

        # Open in editor if available
        if __flo_has_command zed
            zed "$worktree_path"
        else if __flo_has_command code
            code "$worktree_path"
        else if __flo_has_command cursor
            cursor "$worktree_path"
        end

        return 0
    else
        return 1
    end
end
