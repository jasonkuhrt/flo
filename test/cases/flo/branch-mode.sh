#!/bin/bash

setup_temp_repo

FLO=$(flo feat/test-branch 2>&1)
WORKTREE_PATH=$(get_worktree_path "feat/test-branch")

assert_output_contains "$FLO" "feat/test-branch" "flo output contains branch name"
assert_dir_exists "$WORKTREE_PATH"

cd_temp_repo
WORKTREE_LIST=$(git worktree list)
assert_output_contains "$WORKTREE_LIST" "feat-test-branch" "Worktree registered with git"

BRANCHES=$(git branch)
assert_output_contains "$BRANCHES" "feat/test-branch" "Branch created"
