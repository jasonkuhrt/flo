setup_temp_repo

# Setup spies before running flo
spy_on zed
spy_on claude

# Test 1: Default behavior (no --claude flag)
flo feat/test-zed-default >/dev/null 2>&1

spy_assert_called zed
spy_assert_called_not claude

# Cleanup worktree for next test
cd_temp_repo
set -l WORKTREE_PATH (get_worktree_path "feat/test-zed-default")
git worktree remove --force "$WORKTREE_PATH" 2>/dev/null
git branch -D feat/test-zed-default 2>/dev/null

# Re-setup spies (clears logs)
spy_on zed
spy_on claude

# Test 2: With --claude flag
flo feat/test-zed-with-claude --claude >/dev/null 2>&1

spy_assert_called zed
spy_assert_called claude /start
