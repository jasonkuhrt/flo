setup_temp_repo

set -l WORKTREE_PATH (get_worktree_path "feat/idempotent")

flo feat/idempotent >/dev/null 2>&1
assert_dir_exists "$WORKTREE_PATH"

cd_temp_repo
run flo feat/idempotent

# Idempotency check - running flo again should succeed without error
assert_output_not_contains Error "No error on existing worktree"
