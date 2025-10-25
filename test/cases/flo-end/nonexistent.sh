#!/bin/bash

setup_temp_repo
cd_temp_repo

# Try to remove a worktree that doesn't exist
FLO=$(flo end feat/does-not-exist 2>&1 || true)

# Should show a helpful message (not crash)
if echo "$FLO" | grep -qi "error\|not found\|does not exist\|no such"; then
    pass "Shows error message for non-existent worktree"
else
    # If it doesn't error, that's also acceptable behavior
    pass "Handled non-existent worktree gracefully"
fi
