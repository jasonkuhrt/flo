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
    echo "test" > test.txt
    git add test.txt
    git commit -q -m "Initial commit"
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
