function __flo_get_worktree_location --description "Get the standard location for a worktree"
    set -l location ~/.git-worktrees/main/(basename (__flo_get_repo_root))
    mkdir -p $location
    echo $location
end
