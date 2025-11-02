setup_temp_repo

flo feat/test-branch >/dev/null 2>&1
set -l WORKTREE_PATH (get_worktree_path "feat/test-branch")

assert_dir_exists "$WORKTREE_PATH"

cd_temp_repo
set -l WORKTREE_LIST (git worktree list)
assert_string_contains feat-test-branch "$WORKTREE_LIST" "Worktree registered with git"

set -l BRANCHES (git branch)
assert_string_contains feat/test-branch "$BRANCHES" "Branch created"
