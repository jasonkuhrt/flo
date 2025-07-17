function __flo_check_gh_auth --description "Check if GitHub CLI is authenticated"
    if not gh auth status >/dev/null 2>&1
        echo "Error: Not authenticated with GitHub CLI"
        echo "Run: gh auth login"
        return 1
    end
    return 0
end
