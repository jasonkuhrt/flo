setup_temp_repo

# Create a worktree from an issue (simulated with branch name pattern)
# Pattern: <prefix>-<number>-<slug>
run flo feat/14-test-issue

# Should be able to remove by issue number
flo end 14 >/dev/null 2>&1

set -l WORKTREE_PATH (get_worktree_path "feat/14-test-issue")
assert_not_dir_exists "$WORKTREE_PATH" "flo end removed worktree by issue number"
