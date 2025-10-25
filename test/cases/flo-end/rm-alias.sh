#!/bin/bash

# Test that 'flo rm' alias works (backwards compatibility)

setup_temp_repo

flo feat/rm-alias-test >/dev/null 2>&1

# Use rm alias (not end) to remove worktree
flo rm feat/rm-alias-test >/dev/null 2>&1

WORKTREE_PATH=$(get_worktree_path "feat/rm-alias-test")

if [[ ! -d "$WORKTREE_PATH" ]]; then
    pass "flo rm alias works (worktree removed)"
else
    fail "flo rm alias failed (worktree still exists)"
fi
