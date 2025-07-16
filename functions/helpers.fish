# Shared utility functions for flo

function __flo_get_repo_root --description "Get the root directory of the git repository"
    # Get the main repository root, not the worktree root
    set -l git_dir (git rev-parse --git-dir 2>/dev/null)
    if test -n "$git_dir"
        # If in a worktree, git-dir points to .git/worktrees/<name>
        if string match -q "*/worktrees/*" $git_dir
            # Extract main repo path from worktree git-dir
            set -l main_git_dir (string replace -r '/worktrees/[^/]+$' '' $git_dir)
            dirname $main_git_dir
        else
            # In main repo
            git rev-parse --show-toplevel 2>/dev/null
        end
    end
end

function __flo_extract_branch_name --description "Extract a clean branch name from issue title"
    set -l input $argv[1]
    # Remove leading numbers and hyphens, convert to lowercase kebab-case
    # Use echo to prevent input being interpreted as flags
    # Remove invalid characters for git branch names
    echo $input | string replace -r '^[0-9]+-' '' | string replace -a ' ' '-' | string replace -a "'" '' | string replace -a '?' '' | string replace -a '!' '' | string replace -a '(' '' | string replace -a ')' '' | string replace -a '[' '' | string replace -a ']' '' | string replace -a '{' '' | string replace -a '}' '' | string replace -a '/' '' | string replace -a '\\' '' | string replace -a ':' '' | string replace -a '*' '' | string replace -a '^' '' | string replace -a '~' '' | string replace -a '@' '' | string replace -a '#' '' | string replace -a '$' '' | string replace -a '%' '' | string replace -a '&' '' | string replace -a '+' '' | string replace -a '=' '' | string replace -a '|' '' | string replace -a '<' '' | string replace -a '>' '' | string replace -a '"' '' | string replace -a '`' '' | string replace -r -- '\\.+$' '' | string replace -r -- '^-+' '' | string replace -r -- '-+$' '' | string lower
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
    __flo_validate_args 1 (count $argv) "__flo_parse_issue_number"; or return 1
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

# Helper functions for flo next command

function __flo_select_issue --description "Let user select from open issues"
    if not __flo_check_gh_auth
        return 1
    end
    
    set -l issues (gh issue list --json number,title --limit 20 2>/dev/null)
    
    if test -z "$issues" -o "$issues" = "[]"
        echo "No open issues found"
        return 1
    end
    
    echo "Open issues:"
    echo $issues | jq -r '.[] | "#\(.number) - \(.title)"' | nl -v 1
    
    read -P "Select issue (1-N): " selection
    
    if test -z "$selection"
        echo "No selection made"
        return 1
    end
    
    # Validate selection is a number
    if not string match -qr '^[0-9]+$' -- $selection
        echo "Invalid selection: $selection"
        return 1
    end
    
    # Get the issue number (array is 0-indexed, display is 1-indexed)
    set -l index (math $selection - 1)
    set -l issue_number (echo $issues | jq -r ".[$index].number" 2>/dev/null)
    
    if test -z "$issue_number" -o "$issue_number" = "null"
        echo "Invalid selection: $selection"
        return 1
    end
    
    echo $issue_number
end

function __flo_prompt_claude_session --description "Prompt user for Claude session ID"
    echo ""
    echo "To resume your Claude session:"
    echo "1. Run '/status' in Claude"
    echo "2. Copy the Session ID from output like:"
    echo "   Session ID: bbf041be-3b3c-4913-9b13-211921ef0048"
    echo ""
    
    read -P "Session ID (or Enter to skip): " session_id
    
    if test -n "$session_id"
        # Basic validation - should be UUID format
        if string match -qr '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' $session_id
            echo $session_id
        else
            echo "Invalid session ID format (should be UUID like: bbf041be-3b3c-4913-9b13-211921ef0048)" >&2
            return 1
        end
    end
end

function __flo_get_current_worktree_name --description "Get current worktree name if in flo worktree"
    set -l current_path (pwd)
    
    # Check if we're in a git worktree (not the main repo)
    set -l worktree_root (git rev-parse --show-toplevel 2>/dev/null)
    set -l git_dir (git rev-parse --git-dir 2>/dev/null)
    
    if test -n "$worktree_root" -a -n "$git_dir"
        # Check if this is a worktree (git-dir contains worktrees/)
        if string match -q "*/worktrees/*" $git_dir
            basename $worktree_root
        end
    end
end

function __flo_remove_current_worktree --description "Remove current worktree safely"
    set -l current_worktree (__flo_get_current_worktree_name)
    if test -n "$current_worktree"
        # Navigate to main repo before removing
        cd (__flo_get_repo_root)
        flo worktree delete $current_worktree
    end
end

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