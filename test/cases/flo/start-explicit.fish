setup_temp_repo
git remote add origin https://github.com/jasonkuhrt/flo-fixture-repo.git

# Test: flo start with explicit command syntax
flo start feat/test-start-command >/dev/null 2>&1

set -l WORKTREE_PATH (get_worktree_path "feat/test-start-command")

# Verify worktree was created
assert_dir_exists "$WORKTREE_PATH" "flo start created worktree"

# Verify branch was created
git show-ref --verify --quiet refs/heads/feat/test-start-command
assert_success "flo start created branch"
