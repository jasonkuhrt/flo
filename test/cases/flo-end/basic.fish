setup_temp_repo

flo feat/rm-test >/dev/null 2>&1

flo rm feat/rm-test --yes >/dev/null 2>&1

set -l WORKTREE_PATH (get_worktree_path "feat/rm-test")
assert_not_dir_exists "$WORKTREE_PATH" "flo rm removed worktree"
