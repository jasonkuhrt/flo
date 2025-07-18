function __flo_get_worktree_location --description "Get the standard location for a worktree"
    set -l repo_name (__flo_get_repo_name); or return
    set -l location ~/worktrees/$repo_name
    if not mkdir -p "$location"
        __flo_error "Failed to create worktree directory: $location"
        return 1
    end
    echo "$location"
end
