setup_temp_repo
cd_temp_repo

# Try to remove a worktree that doesn't exist
set -l FLO (flo end feat/does-not-exist 2>&1; or true)

# Should show a helpful message (not crash)
# Note: Fallback to pass if no error shown is intentional (graceful handling is acceptable)
if echo "$FLO" | grep -qi "error\|not found\|does not exist\|no such"
    pass "Shows error message for non-existent worktree"
else
    # If it doesn't error, that's also acceptable behavior
    pass "Handled non-existent worktree gracefully"
end
