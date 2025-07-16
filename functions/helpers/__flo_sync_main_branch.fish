function __flo_sync_main_branch --description "Sync main branch with upstream"
    set -l main_repo (__flo_get_repo_root)
    if test -n "$main_repo"
        set -l current_dir (pwd)
        cd $main_repo
        
        # Fetch latest changes
        git fetch origin
        
        # Switch to main branch (try main first, then master)
        set -l main_branch "main"
        if not git show-ref --verify --quiet refs/heads/main
            if git show-ref --verify --quiet refs/heads/master
                set main_branch "master"
            else
                echo "Neither 'main' nor 'master' branch found" >&2
                cd $current_dir
                return 1
            end
        end
        
        git checkout $main_branch
        git pull origin $main_branch
        
        # Return to original directory
        cd $current_dir
    else
        echo "Could not find repository root" >&2
        return 1
    end
end