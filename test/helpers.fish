# Flo-specific test helpers
# Auto-sourced by test framework
# Variables available: $TEST_DIR, $PROJECT_ROOT

# Setup temp repo with git initialized
function setup_temp_repo
    cd "$TEST_CASE_TEMP_DIR"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config init.defaultBranch main
    echo test >test.txt
    git add test.txt
    git commit -q -m "Initial commit"
    # Ensure we're on a proper branch (not detached HEAD)
    git checkout -B main 2>/dev/null; or true
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

# Find worktree directory by pattern
# Only finds worktrees belonging to current TEST_CASE_TEMP_DIR to avoid test pollution
function find_worktree
    set -l pattern $argv[1]
    set -l repo_prefix (basename "$TEST_CASE_TEMP_DIR")
    find (dirname "$TEST_CASE_TEMP_DIR") -maxdepth 1 -type d -name "$repo_prefix"_"*$pattern*" 2>/dev/null | head -1
end

# Load flo CLI framework once - defines the flo function
source "$PROJECT_ROOT/functions/flo.fish"

# Setup worktree for a GitHub issue and cd into it
# Usage: setup_issue_worktree [issue_number] [search_pattern]
# Defaults: issue_number=17, search_pattern="17-test-fixture"
# Guarantees:
#   - Worktree is created and can be found
#   - Changes to worktree directory
#   - .claude directory exists (issue mode creates it)
#   - .claude/CLAUDE.local.md exists (issue mode creates it)
#   - If main repo has .gitignore, worktree has it too
# Fails the test with clear error if guarantees not met
function setup_issue_worktree
    set -l issue_number (test (count $argv) -ge 1; and echo $argv[1]; or echo 17)
    set -l search_pattern (test (count $argv) -ge 2; and echo $argv[2]; or echo "17-test-fixture")

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
