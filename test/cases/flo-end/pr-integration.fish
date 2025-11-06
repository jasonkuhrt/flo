# Test PR integration with flo end
tags slow gh

setup_temp_repo

# Test 1: Success path - Merge PR with passing checks
cd_temp_repo

# Create a worktree and push to GitHub
flo feat/pr-test-1 >/dev/null 2>&1
set -l WORKTREE_PATH (get_worktree_path "feat/pr-test-1")
cd "$WORKTREE_PATH"

# Make a commit
echo "test content" >pr-test.txt
git add pr-test.txt
git commit -m "Test commit for PR" >/dev/null 2>&1

# Push branch and create PR (requires GitHub remote)
git push -u origin feat/pr-test-1 >/dev/null 2>&1
gh pr create --title "Test PR" --body "Test PR for integration" --head feat/pr-test-1 >/dev/null 2>&1

# End worktree (should merge PR)
set -l OUTPUT (flo end --yes --resolve success 2>&1)

# Verify PR was merged
assert_string_contains "Merged PR" "$OUTPUT" "Output confirms PR merge"

# Verify worktree removed
assert_not_dir_exists "$WORKTREE_PATH" "Worktree removed after successful PR merge"

# Verify main branch synced
cd_temp_repo
set -l CURRENT_BRANCH (git branch --show-current)
assert_string_equals main "$CURRENT_BRANCH" "Switched to main branch after merge"

# Test 2: Success path - No PR exists (graceful skip)
cd_temp_repo
flo feat/no-pr-test >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/no-pr-test")
cd "$WORKTREE_PATH"

# Don't create a PR, just end the worktree
set OUTPUT (flo end --yes --resolve success 2>&1)

# Should skip PR operations gracefully
assert_string_contains "No PR found" "$OUTPUT" "Gracefully handles missing PR"
assert_not_string_contains "Merged PR" "$OUTPUT" "Does not attempt to merge non-existent PR"

# Worktree should still be removed
assert_not_dir_exists "$WORKTREE_PATH" "Worktree removed even without PR"

# Test 3: Success path - PR already merged (idempotent)
cd_temp_repo
flo feat/already-merged >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/already-merged")
cd "$WORKTREE_PATH"

# Push and create PR
echo content >file.txt
git add file.txt
git commit -m Test >/dev/null 2>&1
git push -u origin feat/already-merged >/dev/null 2>&1
gh pr create --title "Already merged test" --body Test --head feat/already-merged >/dev/null 2>&1

# Manually merge the PR
gh pr merge feat/already-merged --squash --delete-branch >/dev/null 2>&1

# Try to end again (should be idempotent)
set OUTPUT (flo end --yes --resolve success 2>&1)

# Should handle already-merged gracefully
assert_string_contains "PR already merged" "$OUTPUT" "Detects already-merged PR"
assert_not_dir_exists "$WORKTREE_PATH" "Still removes worktree"

# Test 4: Abort path - Close open PR
cd_temp_repo
flo feat/abort-test >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/abort-test")
cd "$WORKTREE_PATH"

# Push and create PR
echo "abort content" >abort.txt
git add abort.txt
git commit -m "Abort test" >/dev/null 2>&1
git push -u origin feat/abort-test >/dev/null 2>&1
gh pr create --title "Abort test PR" --body "Will be closed" --head feat/abort-test >/dev/null 2>&1

# End with abort
set OUTPUT (flo end --yes --resolve abort 2>&1)

# Verify PR was closed
assert_string_contains "Closed PR" "$OUTPUT" "Output confirms PR closed"

# Verify worktree removed
assert_not_dir_exists "$WORKTREE_PATH" "Worktree removed after abort"

# Verify PR is actually closed on GitHub
set -l PR_STATE (gh pr view feat/abort-test --json state --jq .state 2>/dev/null)
assert_string_equals CLOSED "$PR_STATE" "PR state is CLOSED on GitHub"

# Test 5: Abort path - No PR exists (graceful skip)
cd_temp_repo
flo feat/abort-no-pr >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/abort-no-pr")
cd "$WORKTREE_PATH"

# End with abort (no PR created)
set OUTPUT (flo end --yes --resolve abort 2>&1)

# Should skip PR close gracefully
assert_string_contains "No PR found" "$OUTPUT" "Gracefully handles missing PR in abort mode"
assert_not_string_contains "Closed PR" "$OUTPUT" "Does not attempt to close non-existent PR"

# Worktree should still be removed
assert_not_dir_exists "$WORKTREE_PATH" "Worktree removed even without PR in abort mode"

# Test 6: Abort path - PR already closed (idempotent)
cd_temp_repo
flo feat/already-closed >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/already-closed")
cd "$WORKTREE_PATH"

# Push and create PR
echo "closed content" >closed.txt
git add closed.txt
git commit -m "Closed test" >/dev/null 2>&1
git push -u origin feat/already-closed >/dev/null 2>&1
gh pr create --title "Already closed test" --body Test --head feat/already-closed >/dev/null 2>&1

# Manually close the PR
gh pr close feat/already-closed >/dev/null 2>&1

# Try to abort again (should be idempotent)
set OUTPUT (flo end --yes --resolve abort 2>&1)

# Should handle already-closed gracefully
assert_string_contains "PR already closed" "$OUTPUT" "Detects already-closed PR"
assert_not_dir_exists "$WORKTREE_PATH" "Still removes worktree"
