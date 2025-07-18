function __flo_check_remote_branch --description "Check if a branch exists on remote"
    set -l branch $argv[1]
    set -l remote $argv[2]

    # Default to origin if no remote specified
    if test -z "$remote"
        set remote origin
    end

    if test -z "$branch"
        __flo_error "No branch specified"
        return 1
    end

    # Check if branch exists on remote
    if git ls-remote --heads $remote $branch 2>/dev/null | grep -q $branch
        return 0
    end

    return 1
end
