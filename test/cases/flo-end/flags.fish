# Test flag behavior for flo end
tags slow gh

setup_temp_repo

# Test 1: --ignore pr skips PR operations
cd_temp_repo
flo feat/ignore-pr-test >/dev/null 2>&1
set -l WORKTREE_PATH (get_worktree_path "feat/ignore-pr-test")
cd "$WORKTREE_PATH"

# Push and create PR
echo content >test.txt
git add test.txt
git commit -m "Test commit" >/dev/null 2>&1
git push -u origin feat/ignore-pr-test >/dev/null 2>&1
gh pr create --title "Ignore PR test" --body "Should not be touched" --head feat/ignore-pr-test >/dev/null 2>&1

# End with --ignore pr
set -l OUTPUT (flo end --yes --ignore pr --resolve success 2>&1)

# Should not merge or close PR
assert_not_string_contains "Merged PR" "$OUTPUT" "Does not merge PR with --ignore pr"
assert_not_string_contains "Closed PR" "$OUTPUT" "Does not close PR with --ignore pr"

# Worktree should still be removed
assert_not_dir_exists "$WORKTREE_PATH" "Worktree removed even with --ignore pr"

# PR should still be open
set -l PR_STATE (gh pr view feat/ignore-pr-test --json state --jq .state 2>/dev/null)
assert_string_equals OPEN "$PR_STATE" "PR remains open with --ignore pr"

# Cleanup
cd_temp_repo
gh pr close feat/ignore-pr-test --delete-branch >/dev/null 2>&1

# Test 2: --ignore worktree skips local cleanup
cd_temp_repo
flo feat/ignore-worktree-test >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/ignore-worktree-test")
cd "$WORKTREE_PATH"

# Push and create PR
echo content >test.txt
git add test.txt
git commit -m "Test commit" >/dev/null 2>&1
git push -u origin feat/ignore-worktree-test >/dev/null 2>&1
gh pr create --title "Ignore worktree test" --body "PR will be merged" --head feat/ignore-worktree-test >/dev/null 2>&1

# End with --ignore worktree
set OUTPUT (flo end --yes --ignore worktree --resolve success 2>&1)

# Should merge PR
assert_string_contains "Merged PR" "$OUTPUT" "Merges PR with --ignore worktree"

# Worktree should NOT be removed
assert_dir_exists "$WORKTREE_PATH" "Worktree preserved with --ignore worktree"

# Branch should NOT be deleted
cd_temp_repo
set -l BRANCHES (git branch)
assert_string_contains feat/ignore-worktree-test "$BRANCHES" "Branch preserved with --ignore worktree"

# Cleanup
git worktree remove --force "$WORKTREE_PATH" 2>/dev/null
git branch -D feat/ignore-worktree-test 2>/dev/null

# Test 3: --ignore pr --ignore worktree is no-op
cd_temp_repo
flo feat/ignore-all-test >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/ignore-all-test")
cd "$WORKTREE_PATH"

# Push and create PR
echo content >test.txt
git add test.txt
git commit -m "Test commit" >/dev/null 2>&1
git push -u origin feat/ignore-all-test >/dev/null 2>&1
gh pr create --title "Ignore all test" --body "Nothing should happen" --head feat/ignore-all-test >/dev/null 2>&1

# End with both ignore flags
set OUTPUT (flo end --yes --ignore pr --ignore worktree --resolve success 2>&1)
set -l EXIT_CODE $status

# Should succeed but do nothing
test $EXIT_CODE -eq 0
assert_success "Command succeeds with all operations ignored"

# Should not perform any operations
assert_not_string_contains "Merged PR" "$OUTPUT" "Does not merge PR"
assert_not_string_contains "Removed worktree" "$OUTPUT" "Does not remove worktree"
assert_not_string_contains "Deleted branch" "$OUTPUT" "Does not delete branch"

# Everything should be unchanged
assert_dir_exists "$WORKTREE_PATH" "Worktree still exists"
set -l PR_STATE (gh pr view feat/ignore-all-test --json state --jq .state 2>/dev/null)
assert_string_equals OPEN "$PR_STATE" "PR still open"

# Cleanup
cd_temp_repo
gh pr close feat/ignore-all-test --delete-branch >/dev/null 2>&1
git worktree remove --force "$WORKTREE_PATH" 2>/dev/null

# Test 4: --resolve abort changes PR operation to close
cd_temp_repo
flo feat/resolve-abort-test >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/resolve-abort-test")
cd "$WORKTREE_PATH"

# Push and create PR
echo content >test.txt
git add test.txt
git commit -m "Test commit" >/dev/null 2>&1
git push -u origin feat/resolve-abort-test >/dev/null 2>&1
gh pr create --title "Resolve abort test" --body "Will be closed" --head feat/resolve-abort-test >/dev/null 2>&1

# End with --resolve abort
set OUTPUT (flo end --yes --resolve abort 2>&1)

# Should close PR, not merge
assert_string_contains "Closed PR" "$OUTPUT" "Closes PR with --resolve abort"
assert_not_string_contains "Merged PR" "$OUTPUT" "Does not merge PR with --resolve abort"

# PR should be closed
set PR_STATE (gh pr view feat/resolve-abort-test --json state --jq .state 2>/dev/null)
assert_string_equals CLOSED "$PR_STATE" "PR is closed with --resolve abort"

# Worktree should be removed
assert_not_dir_exists "$WORKTREE_PATH" "Worktree removed with --resolve abort"

# Test 5: --resolve success is the default
cd_temp_repo
flo feat/default-resolve-test >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/default-resolve-test")
cd "$WORKTREE_PATH"

# Push and create PR
echo content >test.txt
git add test.txt
git commit -m "Test commit" >/dev/null 2>&1
git push -u origin feat/default-resolve-test >/dev/null 2>&1
gh pr create --title "Default resolve test" --body "Should be merged" --head feat/default-resolve-test >/dev/null 2>&1

# End without --resolve flag (should default to success)
set OUTPUT (flo end --yes 2>&1)

# Should merge PR (default behavior)
assert_string_contains "Merged PR" "$OUTPUT" "Merges PR by default (--resolve success)"

# Test 6: Multiple --ignore flags can be combined
cd_temp_repo
flo feat/multi-ignore-test >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/multi-ignore-test")
cd "$WORKTREE_PATH"

# Create minimal setup
echo content >test.txt
git add test.txt
git commit -m Test >/dev/null 2>&1

# End with multiple ignore flags
set OUTPUT (flo end --yes --ignore pr --ignore worktree 2>&1)

# Should do nothing
assert_dir_exists "$WORKTREE_PATH" "Worktree exists with multiple ignore flags"

# Cleanup
cd_temp_repo
git worktree remove --force "$WORKTREE_PATH" 2>/dev/null
git branch -D feat/multi-ignore-test 2>/dev/null

# Test 7: Invalid --resolve value shows error
cd_temp_repo
flo feat/invalid-resolve-test >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/invalid-resolve-test")
cd "$WORKTREE_PATH"

# Try invalid --resolve value
set OUTPUT (flo end --yes --resolve invalid 2>&1)
set EXIT_CODE $status

# Should fail with error
test $EXIT_CODE -ne 0
assert_success "Command fails with invalid --resolve value"
assert_string_contains invalid "$OUTPUT" "Shows error for invalid --resolve value"

# Cleanup
cd_temp_repo
git worktree remove --force "$WORKTREE_PATH" 2>/dev/null
git branch -D feat/invalid-resolve-test 2>/dev/null
