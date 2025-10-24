#!/bin/bash

# Test hooks for flo
# Define special functions: before_all, after_each, after_all

before_all() {
    # Clean up stale worktrees from previous test runs
    # This prevents flaky tests caused by leftover worktrees in /tmp
    # macOS mktemp creates dirs in /var/folders/xx/yyy/T/, need maxdepth 5
    find /var/folders -maxdepth 5 -name "tmp.*_feat-*" -type d 2>/dev/null | while read -r dir; do
        rm -rf "$dir" 2>/dev/null
    done
}

after_each() {
    # Clean up worktrees created by tests
    local temp_repo_parent=$(dirname "$TEMP_REPO")
    local temp_repo_base=$(basename "$TEMP_REPO")
    cd /tmp 2>/dev/null
    rm -rf "$TEMP_REPO" "$temp_repo_parent/${temp_repo_base}_"* 2>/dev/null
}

# Uncomment to add after_all hook:
# after_all() {
#     echo "All tests complete!"
# }
