setup_temp_repo

set -l WORKTREE_PATH (get_worktree_path "feat/idempotent")

flo feat/idempotent >/dev/null 2>&1
assert_dir_exists "$WORKTREE_PATH"

cd_temp_repo
set -g OUTPUT (flo feat/idempotent 2>&1)

# Idempotency check - running flo again should succeed without error
assert_not_string_contains Error "$OUTPUT" "No error on existing worktree"
