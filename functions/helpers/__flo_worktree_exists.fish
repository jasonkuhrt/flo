function __flo_worktree_exists --description "Check if a worktree exists"
    set -l name $argv[1]
    git worktree list | string match -q "*/$name *"
end