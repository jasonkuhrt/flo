# Flo-specific test helpers
# Auto-sourced by test framework
# Variables available: $TEST_DIR, $PROJECT_ROOT

# Setup temp repo with git initialized
# For PR tests, this clones from a dedicated fixture repo to avoid polluting main flo repo
function setup_temp_repo
    # Clean temp dir first (before_each hook may have created spy directories)
    rm -rf "$TEST_CASE_TEMP_DIR"
    mkdir -p "$TEST_CASE_TEMP_DIR"
    cd "$TEST_CASE_TEMP_DIR"

    # Clone from fixture repository (dedicated for tests, can be freely polluted)
    # MUST use full clone (not --depth 1) so feature branches share ancestry with remote main
    git clone --quiet git@github.com:jasonkuhrt/flo-fixture-repo.git . 2>/dev/null

    if test $status -ne 0
        # Fallback to init if clone fails (e.g., no network, no auth)
        git init -q
        git config init.defaultBranch main
        git remote add origin git@github.com:jasonkuhrt/flo-fixture-repo.git 2>/dev/null; or true
        echo test >test.txt
        git add test.txt
        git commit -q -m "Initial commit"
    end

    # Configure git user
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Ensure we're on main branch
    # IMPORTANT: Use plain checkout (not -B) to preserve cloned branch history
    # -B would reset main and destroy shared ancestry with origin/main
    git checkout main 2>/dev/null; or git checkout -b main 2>/dev/null; or true

    # CRITICAL: Checkout a test branch (not main) to avoid Git worktree conflicts
    # When gh pr merge runs, it needs to checkout main internally.
    # Git won't allow main to be checked out in multiple worktrees simultaneously.
    # By staying on test-runner branch, we free up main for gh pr merge.
    git checkout -B test-runner 2>/dev/null; or true
end

# Change to temp repo directory
function cd_temp_repo
    cd "$TEST_CASE_TEMP_DIR"
end

# Get worktree path from branch name
function get_worktree_path
    set -l branch $argv[1]
    set -l sanitized (string replace -a '/' '-' $branch)
    echo "$TEST_CASE_TEMP_DIR"_"$sanitized"
end

# Change to worktree directory with error checking
# FAILS the test if the worktree doesn't exist - prevents silent failures that pollute project root
# Usage: cd_worktree <branch-name>  OR  cd_worktree $WORKTREE_PATH
function cd_worktree
    set -l target $argv[1]
    set -l path

    # If it looks like a path (starts with / or contains _), use directly
    # Otherwise, treat as branch name and resolve
    if string match -q '/*' "$target"; or string match -q '*_*' "$target"
        set path "$target"
    else
        set path (get_worktree_path "$target")
    end

    if not test -d "$path"
        fail "cd_worktree: Directory does not exist: $path"
        echo "  Hint: Did 'flo <branch>' succeed? Check worktree was created." >&2
        return 1
    end

    cd "$path"
    or begin
        fail "cd_worktree: Failed to cd to: $path"
        return 1
    end
end

# Find worktree directory by pattern
# Only finds worktrees belonging to current TEST_CASE_TEMP_DIR to avoid test pollution
function find_worktree
    set -l pattern $argv[1]
    set -l repo_prefix (basename "$TEST_CASE_TEMP_DIR")
    find (dirname "$TEST_CASE_TEMP_DIR") -maxdepth 1 -type d -name "$repo_prefix"_"*$pattern*" 2>/dev/null | head -1
end

# Strip ANSI escape codes from string
# Usage: strip_ansi "$string"
function strip_ansi
    set -l input $argv[1]
    # Remove ANSI escape sequences (colors, formatting)
    string replace -ra '\x1b\[[0-9;]*[mGKHF]' '' "$input"
end

# Load flo CLI framework once - defines the flo function
source "$PROJECT_ROOT/functions/flo.fish"

# Setup worktree for a GitHub issue and cd into it
# Usage: setup_issue_worktree [issue_number] [search_pattern]
# Defaults: issue_number=1, search_pattern="1-test-fixture"
# Guarantees:
#   - Worktree is created and can be found
#   - Changes to worktree directory
#   - .claude directory exists (issue mode creates it)
#   - .claude/CLAUDE.local.md exists (issue mode creates it)
#   - If main repo has .gitignore, worktree has it too
# Fails the test with clear error if guarantees not met
function setup_issue_worktree
    set -l issue_number (test (count $argv) -ge 1; and echo $argv[1]; or echo 1)
    set -l search_pattern (test (count $argv) -ge 2; and echo $argv[2]; or echo "1-test-fixture")

    # Clean up any stale worktrees/branches for this issue first
    git worktree list 2>/dev/null | grep "$search_pattern" | awk '{print $1}' | xargs -I {} git worktree remove --force {} 2>/dev/null; or true
    git branch -D "feat/$search_pattern-do-not-close" 2>/dev/null; or true

    # Create worktree
    flo "$issue_number" >/dev/null 2>&1

    set -l worktree_path (find_worktree "$search_pattern")

    if test -z "$worktree_path"
        fail "Worktree not created for issue $issue_number"
        exit 1
    end

    cd "$worktree_path"

    # Verify guarantees
    if not test -d .claude
        fail "Issue mode should create .claude directory (not found in $worktree_path)"
        exit 1
    end

    if not test -f .claude/CLAUDE.local.md
        fail "Issue mode should create .claude/CLAUDE.local.md (not found in $worktree_path)"
        exit 1
    end

    # If main repo has .gitignore, worktree must have it too
    # (git worktrees share tracked files from the parent commit)
    set -l main_repo (git worktree list --porcelain | grep "^worktree" | head -1 | awk '{print $2}')
    if test -f "$main_repo/.gitignore"
        if not test -f .gitignore
            fail ".gitignore exists in main repo but missing in worktree (git worktree issue)"
            exit 1
        end
    end
end
