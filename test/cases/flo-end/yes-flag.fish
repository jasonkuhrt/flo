# Test --yes and -y flags for non-interactive removal

setup_temp_repo

# Test 1: --yes flag (no stdin, removes worktree)
flo feat/yes-test >/dev/null 2>&1
set -l WORKTREE_PATH (get_worktree_path "feat/yes-test")

# Enter the worktree
cd "$WORKTREE_PATH"

# Remove with --yes (no stdin provided)
run flo end --yes

# Should succeed without prompting
assert_output_contains "Removed worktree" "--yes flag removes worktree without prompt"

# Verify worktree was actually removed
assert_not_dir_exists "$WORKTREE_PATH" "--yes flag: worktree directory removed"

# Test 2: -y short form
cd_temp_repo
flo feat/short-yes-test >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/short-yes-test")
cd "$WORKTREE_PATH"

run flo end -y

assert_output_contains "Removed worktree" "-y short form works"

# Test 3: --yes with --force combined
cd_temp_repo
run flo feat/yes-force-test
set WORKTREE_PATH (get_worktree_path "feat/yes-force-test")
cd "$WORKTREE_PATH"

# Create uncommitted change
echo test >uncommitted.txt

set OUTPUT (flo end --yes --force 2>&1)

assert_string_contains "Removed worktree" "$OUTPUT" "--yes --force combined flags work"

assert_not_dir_exists "$WORKTREE_PATH" "--yes --force: worktree directory removed"

# Test 4: --yes with specific worktree (not current directory)
cd_temp_repo
flo feat/specific-yes-test >/dev/null 2>&1

# Remove from main repo (not from within the worktree)
set OUTPUT (flo end feat/specific-yes-test --yes 2>&1)
set WORKTREE_PATH (get_worktree_path "feat/specific-yes-test")

# Note: When removing specific worktree (not current), there's no prompt anyway
# But --yes should still work without error
assert_not_dir_exists "$WORKTREE_PATH" "--yes with specific worktree works"
