#!/bin/bash

# Test that creating a new branch does NOT show "fatal: invalid reference" error
# This verifies that the error from the first git worktree add attempt is properly suppressed

setup_temp_repo

# Create a new branch (should not exist yet)
FLO=$(flo feat/test-new-branch 2>&1)

# Assert no "fatal: invalid reference" error appears
assert_output_not_contains "$FLO" "fatal: invalid reference" \
    "No 'fatal: invalid reference' error shown when creating new branch"

# Verify worktree was created successfully (positive case)
WORKTREE_PATH=$(get_worktree_path "feat/test-new-branch")
assert_dir_exists "$WORKTREE_PATH"
