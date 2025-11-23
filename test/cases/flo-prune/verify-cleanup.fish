setup_temp_repo

# Create a worktree
run flo feat/prune-test
set -l WORKTREE_PATH (get_worktree_path "feat/prune-test")

# Verify it exists in git metadata
cd_temp_repo
set -l BEFORE (git worktree list)
assert_string_contains prune-test "$BEFORE" "Worktree registered before manual deletion"

# Manually delete the worktree directory (simulating user mistake)
rm -rf "$WORKTREE_PATH"

# Verify git still thinks it exists (orphaned metadata)
run git worktree list
assert_output_contains prune-test "Git metadata still exists after manual deletion"

# Run flo prune to clean up
flo prune >/dev/null 2>&1

# Verify git metadata is cleaned up
run git worktree list
assert_output_not_contains prune-test "Git metadata cleaned up by prune"
