function __flo_is_main_branch --description "Check if a branch is main or master"
    set -l branch $argv[1]

    # If no branch provided, check current branch
    if test -z "$branch"
        set branch (git branch --show-current 2>/dev/null)
    end

    if test -z "$branch"
        return 1
    end

    # Check if it's main or master
    if test "$branch" = main -o "$branch" = master
        return 0
    end

    return 1
end
