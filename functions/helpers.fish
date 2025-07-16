# Shared utility functions for flo

function __flo_get_repo_root --description "Get the root directory of the git repository"
    git rev-parse --show-toplevel 2>/dev/null
end

function __flo_extract_branch_name --description "Extract a clean branch name from issue title"
    set -l input $argv[1]
    # Remove leading numbers and hyphens, convert to lowercase kebab-case
    string replace -r '^[0-9]+-' '' $input | string replace -a ' ' '-' | string replace -a "'" '' | string lower
end

function __flo_worktree_exists --description "Check if a worktree exists"
    set -l name $argv[1]
    git worktree list | string match -q "*/$name *"
end

function __flo_get_worktree_location --description "Get the standard location for a worktree"
    set -l location ~/.git-worktrees/main/(basename (__flo_get_repo_root))
    mkdir -p $location
    echo $location
end

function __flo_open_editor --description "Open the configured editor"
    set -l dir $argv[1]
    
    if command -v code >/dev/null
        code $dir
    else if command -v cursor >/dev/null
        cursor $dir
    else
        echo "No supported editor found (VSCode or Cursor)"
        return 1
    end
end

function __flo_parse_issue_number --description "Parse issue number from various formats"
    set -l input $argv[1]
    
    # Try to extract from various formats
    if string match -qr '^[0-9]+$' -- $input
        echo $input
    else if string match -qr '^#[0-9]+$' -- $input
        echo $input | string sub -s 2
    else if string match -qr '^[0-9]+-' -- $input
        echo $input | cut -d'-' -f1
    else
        echo ""
    end
end

function __flo_get_org_repo --description "Get the GitHub org/repo from git remote"
    set -l remote_url (git config --get remote.origin.url)
    
    if test -z "$remote_url"
        echo "No origin remote found" >&2
        return 1
    end
    
    # Extract org/repo from various Git URL formats
    set -l org_repo (string replace -r '.*[:/]([^/]+/[^/]+)(\.git)?$' '$1' $remote_url)
    
    if test -z "$org_repo"
        echo "Could not parse org/repo from remote URL" >&2
        return 1
    end
    
    echo $org_repo
end

function __flo_check_gh_auth --description "Check if GitHub CLI is authenticated"
    if not gh auth status >/dev/null 2>&1
        echo "Error: Not authenticated with GitHub CLI"
        echo "Run: gh auth login"
        return 1
    end
    return 0
end

function __flo_spinner --description "Display a spinner animation"
    set -l pid $argv[1]
    set -l message $argv[2]
    set -l spinners '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏'
    set -l i 1
    
    while kill -0 $pid 2>/dev/null
        printf "\r%s %s" $spinners[$i] $message
        set i (math "($i % 10) + 1")
        sleep 0.1
    end
    
    printf "\r%s\n" (string repeat -n (string length "$spinners[1] $message") " ")
end