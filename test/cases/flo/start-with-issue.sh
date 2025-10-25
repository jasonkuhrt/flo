#!/bin/bash

setup_temp_repo
git remote add origin https://github.com/jasonkuhrt/flo.git

# Test: flo start with issue number (explicit command syntax)
flo start 17 >/dev/null 2>&1

# Find the created worktree
WORKTREE_PATH=$(find_worktree "17-test-fixture")

if [[ -z "$WORKTREE_PATH" ]]; then
    fail "flo start did not create worktree for issue #17"
    exit 1
fi

# Verify worktree directory exists
if [[ -d "$WORKTREE_PATH" ]]; then
    pass "flo start created worktree from issue number"
else
    fail "Worktree directory not found: $WORKTREE_PATH"
fi

# Verify branch was created with correct pattern (feat/17-...)
if git show-ref --verify --quiet refs/heads/feat/17-test-fixture-do-not-close; then
    pass "flo start created branch from issue"
else
    fail "Branch not created for issue #17"
fi

# Verify Claude context was created (issue mode)
if [[ -f "$WORKTREE_PATH/.claude/CLAUDE.local.md" ]]; then
    pass "flo start created Claude context for issue"
else
    fail "Claude context not created"
fi
