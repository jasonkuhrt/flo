function __flo_create_worktree --description "Create a git worktree for a branch"
    set -l branch_name $argv[1]

    if test -z "$branch_name"
        echo "Error: Branch name required" >&2
        return 1
    end

    # Get the worktree location
    set -l repo_root (__flo_get_repo_root)
    if test -z "$repo_root"
        echo "Error: Not in a git repository" >&2
        return 1
    end
    
    set -l repo_name (basename $repo_root)
    set -l location ~/worktrees/$repo_name
    mkdir -p $location

    set -l worktree_path "$location/$branch_name"

    # Check if worktree already exists
    if __flo_worktree_exists $branch_name
        echo "Worktree '$branch_name' already exists" >&2
        return 1
    end

    # Create the worktree
    git worktree add -b $branch_name $worktree_path

    if test $status -eq 0
        echo "Created worktree at: $worktree_path"

        # Open in editor if available
        if command -q zed
            zed $worktree_path
        else if command -q code
            code $worktree_path
        else if command -q cursor
            cursor $worktree_path
        end

        return 0
    else
        return 1
    end
end
