# Test validation logic for flo end
tags slow gh

setup_temp_repo

# Test 1: Block on failing PR checks (success mode)
cd_temp_repo
flo feat/failing-checks >/dev/null 2>&1
set -l WORKTREE_PATH (get_worktree_path "feat/failing-checks")
cd "$WORKTREE_PATH"

# Push and create PR
echo content >test.txt
git add test.txt
git commit -m "Test with failing checks" >/dev/null 2>&1
git push -u origin feat/failing-checks >/dev/null 2>&1
gh pr create --title "Failing checks test" --body Test --head feat/failing-checks >/dev/null 2>&1

# Wait for checks to start (they will fail or be pending)
# Note: In real scenarios, checks need to actually fail
# For testing, we'll simulate by checking for non-SUCCESS status

# Try to end (should block)
set -l OUTPUT (flo end --yes --resolve success 2>&1)
set -l EXIT_CODE $status

# Should fail with validation error
assert_string_contains "PR checks" "$OUTPUT" "Shows PR checks validation error"
test $EXIT_CODE -ne 0
assert_success "Command exits with error when checks not passing"

# Worktree should NOT be removed (validation failed)
assert_dir_exists "$WORKTREE_PATH" "Worktree preserved when validation fails"

# Cleanup
cd_temp_repo
gh pr close feat/failing-checks >/dev/null 2>&1
git worktree remove --force "$WORKTREE_PATH" 2>/dev/null

# Test 2: Block on uncommitted changes (success mode)
cd_temp_repo
flo feat/dirty-worktree >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/dirty-worktree")
cd "$WORKTREE_PATH"

# Create uncommitted changes
echo uncommitted >dirty.txt

# Try to end (should block)
set OUTPUT (flo end --yes --resolve success 2>&1)
set EXIT_CODE $status

# Should fail with validation error
assert_string_contains "uncommitted changes" "$OUTPUT" "Shows dirty worktree validation error"
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
git push -u origin feat/unpushed >/dev/null 2>&1

# Create a local commit (not pushed)
echo unpushed >unpushed.txt
git add unpushed.txt
git commit -m "Unpushed commit" >/dev/null 2>&1

# Try to end (should block)
set OUTPUT (flo end --yes --resolve success 2>&1)
set EXIT_CODE $status

# Should fail with validation error
assert_string_contains "unpushed commits" "$OUTPUT" "Shows unpushed commits validation error"
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
flo feat/force-bypass >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/force-bypass")
cd "$WORKTREE_PATH"

# Create dirty worktree
echo uncommitted >dirty.txt

# Push and commit something else
echo committed >committed.txt
git add committed.txt
git commit -m Committed >/dev/null 2>&1
git push -u origin feat/force-bypass >/dev/null 2>&1

# Create unpushed commit
echo unpushed >unpushed.txt
git add unpushed.txt
git commit -m Unpushed >/dev/null 2>&1

# End with --force (should bypass validations)
set OUTPUT (flo end --yes --force --resolve success 2>&1)
set EXIT_CODE $status

# Should succeed despite dirty state and unpushed commits
test $EXIT_CODE -eq 0
assert_success "Command succeeds with --force despite validations"

# Worktree should be removed
assert_not_dir_exists "$WORKTREE_PATH" "Worktree removed with --force"

# Cleanup remote branch
cd_temp_repo
git push origin --delete feat/force-bypass 2>/dev/null

# Test 5: Abort mode has no validations
cd_temp_repo
flo feat/abort-no-validation >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/abort-no-validation")
cd "$WORKTREE_PATH"

# Create dirty worktree with unpushed commits
echo uncommitted >dirty.txt
echo committed >committed.txt
git add committed.txt
git commit -m "Test commit" >/dev/null 2>&1
git push -u origin feat/abort-no-validation >/dev/null 2>&1
echo unpushed >unpushed.txt
git add unpushed.txt
git commit -m Unpushed >/dev/null 2>&1

# Create PR
gh pr create --title "Abort validation test" --body Test --head feat/abort-no-validation >/dev/null 2>&1

# End with abort (should succeed despite dirty state)
set OUTPUT (flo end --yes --resolve abort 2>&1)
set EXIT_CODE $status

# Should succeed without validation errors
test $EXIT_CODE -eq 0
assert_success "Abort mode succeeds despite dirty state and unpushed commits"

# Should not show validation errors
assert_not_string_contains "uncommitted changes" "$OUTPUT" "No validation error for dirty worktree in abort mode"
assert_not_string_contains "unpushed commits" "$OUTPUT" "No validation error for unpushed commits in abort mode"

# Worktree should be removed
assert_not_dir_exists "$WORKTREE_PATH" "Worktree removed in abort mode"

# PR should be closed
set -l PR_STATE (gh pr view feat/abort-no-validation --json state --jq .state 2>/dev/null)
assert_string_equals CLOSED "$PR_STATE" "PR closed in abort mode"

# Cleanup
cd_temp_repo
git push origin --delete feat/abort-no-validation 2>/dev/null
