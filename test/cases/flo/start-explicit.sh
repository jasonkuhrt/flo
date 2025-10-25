#!/bin/bash

setup_temp_repo
git remote add origin https://github.com/jasonkuhrt/flo.git

# Test: flo start with explicit command syntax
flo start feat/test-start-command >/dev/null 2>&1

WORKTREE_PATH=$(get_worktree_path "feat/test-start-command")

# Verify worktree was created
if [[ -d "$WORKTREE_PATH" ]]; then
    pass "flo start created worktree"
else
    fail "flo start failed to create worktree (path: $WORKTREE_PATH)"
fi

# Verify branch was created
if git show-ref --verify --quiet refs/heads/feat/test-start-command; then
    pass "flo start created branch"
else
    fail "flo start failed to create branch"
fi
