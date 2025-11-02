setup_temp_repo

# Create a worktree from an issue (simulated with branch name pattern)
# Pattern: <prefix>-<number>-<slug>
flo feat/14-test-issue >/dev/null 2>&1

# Should be able to remove by issue number
flo end 14 >/dev/null 2>&1

set -l WORKTREE_PATH (get_worktree_path "feat/14-test-issue")
assert_not_dir_exists "$WORKTREE_PATH" "flo end removed worktree by issue number"
