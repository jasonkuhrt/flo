#!/bin/bash

# Test hooks for flo
# Define special functions: after_each, after_all

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
