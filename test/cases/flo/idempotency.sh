#!/bin/bash

setup_temp_repo

WORKTREE_PATH=$(get_worktree_path "feat/idempotent")

flo feat/idempotent >/dev/null 2>&1
assert_dir_exists "$WORKTREE_PATH"

cd_temp_repo
FLO=$(flo feat/idempotent 2>&1)

assert_output_contains "$FLO" "already exists" "Detected existing worktree"

if echo "$FLO" | grep -q "Error"; then
    fail "Errored on existing worktree"
else
    pass "No error on existing worktree"
fi
