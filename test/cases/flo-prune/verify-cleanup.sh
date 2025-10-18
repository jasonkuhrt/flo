#!/bin/bash

setup_temp_repo

# Create a worktree
flo feat/prune-test >/dev/null 2>&1
WORKTREE_PATH=$(get_worktree_path "feat/prune-test")

# Verify it exists in git metadata
cd_temp_repo
BEFORE=$(git worktree list)
assert_output_contains "$BEFORE" "prune-test" "Worktree registered before manual deletion"

# Manually delete the worktree directory (simulating user mistake)
rm -rf "$WORKTREE_PATH"

# Verify git still thinks it exists (orphaned metadata)
ORPHANED=$(git worktree list 2>&1 || true)
if echo "$ORPHANED" | grep -q "prune-test"; then
    pass "Git metadata still exists after manual deletion"
fi

# Run flo prune to clean up
flo prune >/dev/null 2>&1

# Verify git metadata is cleaned up
AFTER=$(git worktree list 2>&1 || true)
if echo "$AFTER" | grep -q "prune-test"; then
    fail "Git metadata still exists after prune"
else
    pass "Git metadata cleaned up by prune"
fi
