# Test PR integration with flo end
tags slow gh

setup_temp_repo

# Test 1: Success path - Merge PR with passing checks
cd_temp_repo

# Use timestamp to ensure unique branch names across test runs
set -l timestamp (date +%s)
set -l test_branch "feat/pr-test-$timestamp"

# Create a worktree and push to GitHub
flo "$test_branch" >/dev/null 2>&1
set -l WORKTREE_PATH (get_worktree_path "$test_branch")
cd "$WORKTREE_PATH"

# Make a commit with unique content
set -l unique_file "pr-test-$timestamp.txt"
echo "test content" >"$unique_file"
git add "$unique_file"
git commit -m "Test commit for PR" >/dev/null 2>&1

echo "DEBUG: Git log before push:"
git log --oneline -3
echo "DEBUG: Remote branches:"
git branch -r
echo "DEBUG: Merge base with origin/main:"
git merge-base HEAD origin/main 2>&1; or echo "No merge base found"

# Push branch and create PR (requires GitHub remote)
git push -u origin "$test_branch" >/dev/null 2>&1
gh pr create --title "Test PR $timestamp" --body "Test PR for integration" --head "$test_branch"
echo "DEBUG: PR create exit: $status"

# End worktree (should merge PR)
# Use --force to skip validation (PR checks may be pending in test environment)
run flo end --yes --force --resolve success
echo "DEBUG flo end output: $RUN_OUTPUT"
echo "DEBUG flo end exit: $status"

# Verify PR was merged
set -l clean_output (strip_ansi "$RUN_OUTPUT")
assert_string_contains "Merged PR" "$clean_output" "Output confirms PR merge"

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

# Don't create a PR, just end the worktree (use --force to skip PR validation)
run flo end --yes --force --resolve success

# Should skip PR operations gracefully
assert_string_contains "No PR found" "$RUN_OUTPUT" "Gracefully handles missing PR"
assert_not_string_contains "Merged PR" "$RUN_OUTPUT" "Does not attempt to merge non-existent PR"

# Worktree should still be removed
assert_not_dir_exists "$WORKTREE_PATH" "Worktree removed even without PR"

# Test 3: Success path - PR already merged (idempotent)
cd_temp_repo
run flo feat/already-merged
set WORKTREE_PATH (get_worktree_path "feat/already-merged")
cd "$WORKTREE_PATH"

# Push and create PR
set unique_file "file-"(date +%s)".txt"
echo content >"$unique_file"
git add "$unique_file"
git commit -m Test >/dev/null 2>&1
git push -u origin feat/already-merged --force >/dev/null 2>&1
gh pr create --title "Already merged test" --body Test --head feat/already-merged >/dev/null 2>&1

# Manually merge the PR
gh pr merge feat/already-merged --squash --delete-branch >/dev/null 2>&1

# Try to end again (should be idempotent)
run flo end --yes --resolve success

# Should handle already-merged gracefully
assert_string_contains "already merged" "$RUN_OUTPUT" "Detects already-merged PR"
assert_not_dir_exists "$WORKTREE_PATH" "Still removes worktree"

# Test 4: Abort path - Close open PR
cd_temp_repo
flo feat/abort-test >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/abort-test")
cd "$WORKTREE_PATH"

# Push and create PR
set unique_file "abort-"(date +%s)".txt"
echo "abort content" >"$unique_file"
git add "$unique_file"
git commit -m "Abort test" >/dev/null 2>&1
git push -u origin feat/abort-test --force >/dev/null 2>&1
gh pr create --title "Abort test PR" --body "Will be closed" --head feat/abort-test >/dev/null 2>&1

# Capture PR number before branch deletion
set -l PR_NUMBER (gh pr view feat/abort-test --json number --jq .number 2>/dev/null)

# End with abort
run flo end --yes --resolve abort

# Verify PR was closed
set -l clean_output (strip_ansi "$RUN_OUTPUT")
assert_string_contains "Closed PR" "$clean_output" "Output confirms PR closed"

# Verify worktree removed
assert_not_dir_exists "$WORKTREE_PATH" "Worktree removed after abort"

# Verify PR is actually closed on GitHub (query by number, not branch name)
set -l PR_STATE (gh pr view "$PR_NUMBER" --json state --jq .state 2>/dev/null)
assert_string_equals CLOSED "$PR_STATE" "PR state is CLOSED on GitHub"

# Test 5: Abort path - No PR exists (graceful skip)
cd_temp_repo
flo feat/abort-no-pr >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/abort-no-pr")
cd "$WORKTREE_PATH"

# End with abort (no PR created)
run flo end --yes --resolve abort

# Should skip PR close gracefully
assert_string_contains "No PR found" "$RUN_OUTPUT" "Gracefully handles missing PR in abort mode"
assert_not_string_contains "Closed PR" "$RUN_OUTPUT" "Does not attempt to close non-existent PR"

# Worktree should still be removed
assert_not_dir_exists "$WORKTREE_PATH" "Worktree removed even without PR in abort mode"

# Test 6: Abort path - PR already closed (idempotent)
cd_temp_repo
flo feat/already-closed >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/already-closed")
cd "$WORKTREE_PATH"

# Push and create PR
set unique_file "closed-"(date +%s)".txt"
echo "closed content" >"$unique_file"
git add "$unique_file"
git commit -m "Closed test" >/dev/null 2>&1
git push -u origin feat/already-closed --force >/dev/null 2>&1
gh pr create --title "Already closed test" --body Test --head feat/already-closed >/dev/null 2>&1

# Manually close the PR
gh pr close feat/already-closed >/dev/null 2>&1

# Try to abort again (should be idempotent)
run flo end --yes --resolve abort

# Should handle already-closed gracefully
assert_string_contains "already closed" "$RUN_OUTPUT" "Detects already-closed PR"
assert_not_dir_exists "$WORKTREE_PATH" "Still removes worktree"
