setup_temp_repo

# Create a worktree
flo feat/prune-test >/dev/null 2>&1
set -l WORKTREE_PATH (get_worktree_path "feat/prune-test")

# Verify it exists in git metadata
cd_temp_repo
set -l BEFORE (git worktree list)
assert_string_contains prune-test "$BEFORE" "Worktree registered before manual deletion"

# Manually delete the worktree directory (simulating user mistake)
rm -rf "$WORKTREE_PATH"

# Verify git still thinks it exists (orphaned metadata)
set -g OUTPUT (git worktree list 2>&1; or true)
assert_string_contains prune-test "$OUTPUT" "Git metadata still exists after manual deletion"

# Run flo prune to clean up
flo prune >/dev/null 2>&1

# Verify git metadata is cleaned up
set -g OUTPUT (git worktree list 2>&1; or true)
assert_not_string_contains prune-test "$OUTPUT" "Git metadata cleaned up by prune"
