# Test branch deletion behavior when removing worktrees

setup_temp_repo

# Test 1: Default behavior - branch should be deleted
flo feat/delete-test >/dev/null 2>&1
set -l WORKTREE_PATH (get_worktree_path "feat/delete-test")
cd "$WORKTREE_PATH"

# Verify branch exists before removal
set -l BRANCHES (git branch)
assert_string_contains feat/delete-test "$BRANCHES" "Branch feat/delete-test exists before removal"

# Remove worktree (should also delete branch)
set -l OUTPUT (flo end --yes 2>&1)

# Check output mentions branch deletion
assert_string_contains "Deleted branch" "$OUTPUT" "Output confirms branch deletion"

# Verify branch no longer exists
set BRANCHES (git branch)
assert_not_string_contains feat/delete-test "$BRANCHES" "Branch feat/delete-test deleted after removal"

# Test 2: --keep-branch flag preserves the branch
cd_temp_repo
flo feat/keep-test >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/keep-test")
cd "$WORKTREE_PATH"

set OUTPUT (flo end --yes --keep-branch 2>&1)

# Check output confirms keeping branch
assert_string_contains "Kept branch" "$OUTPUT" "--keep-branch: Output confirms branch kept"

# Return to main repo to check branch
cd_temp_repo

# Verify branch still exists
set BRANCHES (git branch)
assert_string_contains feat/keep-test "$BRANCHES" "--keep-branch: Branch still exists after removal"

# Cleanup
git branch -d feat/keep-test >/dev/null 2>&1

# Test 3: Remove by branch name (not from within worktree)
cd_temp_repo
flo feat/remote-delete >/dev/null 2>&1

# Remove from main repo
flo end feat/remote-delete --yes >/dev/null 2>&1

# Verify branch was deleted
set BRANCHES (git branch)
assert_not_string_contains feat/remote-delete "$BRANCHES" "Branch deleted when removing by name"

# Test 4: -k short form works
cd_temp_repo
flo feat/short-keep >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/short-keep")
cd "$WORKTREE_PATH"

flo end --yes -k >/dev/null 2>&1

# Return to main repo to check branch
cd_temp_repo

set BRANCHES (git branch)
assert_string_contains feat/short-keep "$BRANCHES" "-k short form preserves branch"

# Cleanup
git branch -d feat/short-keep >/dev/null 2>&1

# Test 5: Force delete unmerged branch
cd_temp_repo
flo feat/unmerged-test >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/unmerged-test")
cd "$WORKTREE_PATH"

# Create a commit that's not in main
echo "unmerged content" >unmerged.txt
git add unmerged.txt
git commit -m "Unmerged commit" >/dev/null 2>&1

# Try to remove without --force (git branch -d should fail, but log error)
cd_temp_repo
set OUTPUT (flo end feat/unmerged-test --yes 2>&1)

# Branch deletion should fail with helpful error
assert_string_contains "Failed to delete branch" "$OUTPUT" "Unmerged branch: Shows error message"

# Branch should still exist (deletion failed)
set BRANCHES (git branch)
assert_string_contains feat/unmerged-test "$BRANCHES" "Unmerged branch: Branch still exists after failed deletion"

# Now force delete it
flo feat/unmerged-test >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/unmerged-test")
cd "$WORKTREE_PATH"

set OUTPUT (flo end --yes --force 2>&1)

# With --force, branch should be deleted
assert_string_contains "Deleted branch" "$OUTPUT" "--force: Force-deletes unmerged branch"

set BRANCHES (git branch)
assert_not_string_contains feat/unmerged-test "$BRANCHES" "--force: Unmerged branch deleted"
