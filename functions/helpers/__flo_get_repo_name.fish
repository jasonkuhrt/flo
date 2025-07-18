function __flo_get_repo_name --description "Get the repository name from the current repository"
    set -l repo_root (__flo_get_repo_root)
    if test -z "$repo_root"
        __flo_error "Not in a git repository"
        return 1
    end

    basename $repo_root
end
