# Test validation logic for flo end
tags slow gh

setup_temp_repo

# Test 1: Block on uncommitted changes (success mode)
cd_temp_repo
run flo feat/dirty-worktree
set WORKTREE_PATH (get_worktree_path "feat/dirty-worktree")
cd "$WORKTREE_PATH"

# Create uncommitted changes
echo uncommitted >dirty.txt

# Try to end (should block)
run flo end --yes --resolve success
set EXIT_CODE $status

# Should fail with validation error
assert_output_contains "uncommitted changes" "Shows dirty worktree validation error"
test $EXIT_CODE -ne 0
assert_success "Command exits with error when worktree dirty"

# Worktree should NOT be removed
assert_dir_exists "$WORKTREE_PATH" "Worktree preserved when dirty"

# Cleanup
cd_temp_repo
git worktree remove --force "$WORKTREE_PATH" 2>/dev/null

# Test 3: Block on unpushed commits (success mode)
cd_temp_repo
flo feat/unpushed >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/unpushed")
cd "$WORKTREE_PATH"

# Push to set up tracking
git push -u origin feat/unpushed --force >/dev/null 2>&1

# Create a local commit (not pushed)
echo unpushed >unpushed.txt
git add unpushed.txt
git commit -m "Unpushed commit" >/dev/null 2>&1

# Try to end (should block)
run flo end --yes --resolve success
set EXIT_CODE $status

# Should fail with validation error
assert_output_contains "unpushed commits" "Shows unpushed commits validation error"
test $EXIT_CODE -ne 0
assert_success "Command exits with error when commits unpushed"

# Worktree should NOT be removed
assert_dir_exists "$WORKTREE_PATH" "Worktree preserved when commits unpushed"

# Cleanup
cd_temp_repo
git worktree remove --force "$WORKTREE_PATH" 2>/dev/null
git push origin --delete feat/unpushed 2>/dev/null

# Test 4: --force bypasses all validations
cd_temp_repo
run flo feat/force-bypass
set WORKTREE_PATH (get_worktree_path "feat/force-bypass")
cd "$WORKTREE_PATH"

# Create dirty worktree
echo uncommitted >dirty.txt

# Push and commit something else
echo committed >committed.txt
git add committed.txt
git commit -m Committed >/dev/null 2>&1
git push -u origin feat/force-bypass --force >/dev/null 2>&1

# Create unpushed commit
echo unpushed >unpushed.txt
git add unpushed.txt
git commit -m Unpushed >/dev/null 2>&1

# End with --force (should bypass validations)
run flo end --yes --force --resolve success
set EXIT_CODE $status

# Should succeed despite dirty state and unpushed commits
test $EXIT_CODE -eq 0
assert_success "Command succeeds with --force despite validations"

# Worktree should be removed
assert_not_dir_exists "$WORKTREE_PATH" "Worktree removed with --force"

# Cleanup remote branch
cd_temp_repo
git push origin --delete feat/force-bypass 2>/dev/null

# Test 5: Abort mode has no validations (skips PR check validation)
# Note: We test with unpushed commits (which would block in success mode)
# but keep worktree clean so git worktree remove succeeds
cd_temp_repo
run flo feat/abort-no-validation
set WORKTREE_PATH (get_worktree_path "feat/abort-no-validation")
cd "$WORKTREE_PATH"

# Create commits but keep worktree clean
set -l unique_file "abort-no-validation-"(date +%s)".txt"
echo committed >"$unique_file"
git add "$unique_file"
git commit -m "Test commit" >/dev/null 2>&1
git push -u origin feat/abort-no-validation --force >/dev/null 2>&1

# Create unpushed commit (would fail validation in success mode)
echo unpushed >unpushed.txt
git add unpushed.txt
git commit -m Unpushed >/dev/null 2>&1

# Create PR
gh pr create --title "Abort validation test" --body Test --head feat/abort-no-validation >/dev/null 2>&1

# Capture PR number before branch deletion
set -l PR_NUMBER (gh pr view feat/abort-no-validation --json number --jq .number 2>/dev/null)

# End with abort (should succeed - validation is skipped in abort mode)
run flo end --yes --resolve abort
set EXIT_CODE $status

# Should succeed without validation errors (unpushed commits don't block abort)
test $EXIT_CODE -eq 0
assert_success "Abort mode succeeds despite unpushed commits"

# Should not show validation error for unpushed commits
assert_output_not_contains "unpushed commits" "No validation error for unpushed commits in abort mode"

# Worktree should be removed (clean worktree)
assert_not_dir_exists "$WORKTREE_PATH" "Worktree removed in abort mode"

# PR should be closed (query by number, not branch name)
set -l PR_STATE (gh pr view "$PR_NUMBER" --json state --jq .state 2>/dev/null)
assert_string_equals CLOSED "$PR_STATE" "PR closed in abort mode"

# Cleanup
cd_temp_repo
git push origin --delete feat/abort-no-validation 2>/dev/null
