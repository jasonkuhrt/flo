function __flo_show_diff --description "Show git diff with delta if available"
    set -l diff_args $argv

    # Use delta if available
    if __flo_has_command delta
        # Check if we're in a git repo
        if git rev-parse --git-dir >/dev/null 2>&1
            # Use git diff with delta as pager
            GIT_PAGER=delta git diff $diff_args
        else
            echo "Not in a git repository" >&2
            return 1
        end
    else
        # Fall back to regular git diff
        git diff $diff_args
    end
end
