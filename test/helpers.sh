#!/bin/bash

# Flo-specific test helpers
# Auto-sourced by test framework
# Variables available: $TEST_DIR, $PROJECT_ROOT

# Setup temp repo with git initialized
setup_temp_repo() {
    cd "$TEMP_REPO"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config init.defaultBranch main
    echo "test" > test.txt
    git add test.txt
    git commit -q -m "Initial commit"
    # Ensure we're on a proper branch (not detached HEAD)
    git checkout -B main 2>/dev/null || true
}

# Change to temp repo directory
cd_temp_repo() {
    cd "$TEMP_REPO"
}

# Get worktree path from branch name
get_worktree_path() {
    local branch="$1"
    local sanitized=$(echo "$branch" | tr '/' '-')
    echo "${TEMP_REPO}_${sanitized}"
}

# Find worktree directory by pattern
find_worktree() {
    find "$(dirname "$TEMP_REPO")" -maxdepth 1 -type d -name "*_*$1*" 2>/dev/null | head -1
}

# Bash wrapper for flo command (handles all subcommands via CLI framework)
flo() {
    fish -c "source $PROJECT_ROOT/functions/flo.fish; flo $*"
}

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
setup_issue_worktree() {
    local issue_number="${1:-17}"
    local search_pattern="${2:-17-test-fixture}"

    # Clean up any stale worktrees/branches for this issue first
    git worktree list 2>/dev/null | grep "$search_pattern" | awk '{print $1}' | xargs -I {} git worktree remove --force {} 2>/dev/null || true
    git branch -D "feat/$search_pattern-do-not-close" 2>/dev/null || true

    # Create worktree
    flo "$issue_number" >/dev/null 2>&1

    local worktree_path=$(find_worktree "$search_pattern")

    if [[ -z "$worktree_path" ]]; then
        fail "Worktree not created for issue $issue_number"
        exit 1
    fi

    cd "$worktree_path"

    # Verify guarantees
    if [[ ! -d .claude ]]; then
        fail "Issue mode should create .claude directory (not found in $worktree_path)"
        exit 1
    fi

    if [[ ! -f .claude/CLAUDE.local.md ]]; then
        fail "Issue mode should create .claude/CLAUDE.local.md (not found in $worktree_path)"
        exit 1
    fi

    # If main repo has .gitignore, worktree must have it too
    # (git worktrees share tracked files from the parent commit)
    local main_repo=$(git worktree list --porcelain | grep "^worktree" | head -1 | awk '{print $2}')
    if [[ -f "$main_repo/.gitignore" ]]; then
        if [[ ! -f .gitignore ]]; then
            fail ".gitignore exists in main repo but missing in worktree (git worktree issue)"
            exit 1
        fi
    fi
}
