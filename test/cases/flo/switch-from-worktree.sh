#!/bin/bash

# Test: Running flo from within a worktree should work correctly
# Bug: Used to fail with "Unable to read current working directory"
# because it tried to create "../worktree-name_new-branch" instead of "../project_new-branch"

setup_temp_repo

# Create first worktree and cd into it
FIRST_BRANCH="feat/first-feature"
FIRST_WORKTREE=$(get_worktree_path "$FIRST_BRANCH")
flo "$FIRST_BRANCH" >/dev/null 2>&1
cd "$FIRST_WORKTREE"

# Now run flo from within the first worktree to create a second worktree
SECOND_BRANCH="refactor/second-feature"
SECOND_WORKTREE=$(get_worktree_path "$SECOND_BRANCH")

FLO_OUTPUT=$(flo "$SECOND_BRANCH" 2>&1)

# Verify flo detected the worktree and showed appropriate message
assert_output_contains "$FLO_OUTPUT" "Detected flo worktree" "Should show message about detecting worktree"
assert_output_contains "$FLO_OUTPUT" "switching to main project" "Should show message about switching to main"

# Verify the second worktree was created with correct path
assert_dir_exists "$SECOND_WORKTREE" "Second worktree should be created at correct path"

# Verify git registered the worktree correctly
cd_temp_repo
WORKTREE_LIST=$(git worktree list)
assert_output_contains "$WORKTREE_LIST" "refactor-second-feature" "Second worktree registered with git"

# Verify the branch was created
BRANCHES=$(git branch)
assert_output_contains "$BRANCHES" "refactor/second-feature" "Second branch created"
