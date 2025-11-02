# Test that 'flo rm' alias works (backwards compatibility)

setup_temp_repo

flo feat/rm-alias-test >/dev/null 2>&1

# Use rm alias (not end) to remove worktree
flo rm feat/rm-alias-test >/dev/null 2>&1

set -l WORKTREE_PATH (get_worktree_path "feat/rm-alias-test")

assert_not_dir_exists "$WORKTREE_PATH" "flo rm alias works (worktree removed)"
