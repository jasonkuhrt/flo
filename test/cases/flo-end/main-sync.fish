# Test main branch sync behavior for flo end
tags slow gh

setup_temp_repo

# Test 1: Sync main after successful PR merge
cd_temp_repo

# NOTE: Don't checkout main here! setup_temp_repo intentionally stays on test-runner branch
# because gh pr merge needs to checkout main internally, and Git doesn't allow
# the same branch to be checked out in multiple worktrees simultaneously.

# Use timestamp for unique branch names
set -l sync_timestamp (date +%s)

# Create a worktree and PR
set -l sync_branch "feat/sync-test-$sync_timestamp"
flo "$sync_branch" >/dev/null 2>&1
set -l WORKTREE_PATH (get_worktree_path "$sync_branch")
cd "$WORKTREE_PATH"

# Push and create/merge PR
set -l unique_file "sync-test-$sync_timestamp.txt"
echo content >"$unique_file"
git add "$unique_file"
git commit -m "Test commit" >/dev/null 2>&1
git push -u origin "$sync_branch" --force >/dev/null 2>&1
gh pr create --title "Sync test PR $sync_timestamp" --body Test --head "$sync_branch" >/dev/null 2>&1

# End worktree (should merge PR and sync main)
# Use --force to bypass PR check validation (we're testing sync, not validation)
run flo end --yes --resolve success --force

# Should mention syncing main
assert_output_contains Sync "Output mentions syncing main branch"

# Should be on main branch after operation
cd_temp_repo
set -l CURRENT_BRANCH (git branch --show-current)
assert_string_equals main "$CURRENT_BRANCH" "Switched to main branch after PR merge"

# Main should be up-to-date (git pull should be no-op)
set -l PULL_OUTPUT (git pull origin main 2>&1)
assert_string_contains "up to date" "$PULL_OUTPUT" "Main branch is synced with remote"

# Test 2: Handle main sync failures gracefully
cd_temp_repo
set -l fail_timestamp (date +%s)
set -l fail_branch "feat/sync-fail-$fail_timestamp"
flo "$fail_branch" >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "$fail_branch")
cd "$WORKTREE_PATH"

# Push and create PR
set -l unique_file "sync-fail-$fail_timestamp.txt"
echo content >"$unique_file"
git add "$unique_file"
git commit -m Test >/dev/null 2>&1
git push -u origin "$fail_branch" --force >/dev/null 2>&1
gh pr create --title "Sync fail test $fail_timestamp" --body Test --head "$fail_branch" >/dev/null 2>&1

# Go to main and create a conflicting commit
cd_temp_repo
echo conflict >"conflict-$fail_timestamp.txt"
git add "conflict-$fail_timestamp.txt"
git commit -m "Conflicting commit" >/dev/null 2>&1

# Now end the worktree (sync might fail due to local commits)
cd "$WORKTREE_PATH"
# Use --force to bypass PR check validation (we're testing sync failure handling)
run flo end --yes --resolve success --force
set -l EXIT_CODE $status

# Command should succeed even if sync fails
test $EXIT_CODE -eq 0
assert_success "Command succeeds even when main sync fails"

# Should show warning about sync failure
assert_output_contains sync "Shows message about main sync"

# Worktree should still be removed (cleanup succeeded)
assert_not_dir_exists "$WORKTREE_PATH" "Worktree removed despite sync failure"

# Test 3: Skip sync when --ignore pr used
cd_temp_repo
# Reset main to clean state
git reset --hard HEAD~1 >/dev/null 2>&1

set -l ignore_timestamp (date +%s)
set -l ignore_branch "feat/ignore-pr-sync-$ignore_timestamp"
flo "$ignore_branch" >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "$ignore_branch")
cd "$WORKTREE_PATH"

# Create changes but don't create PR
set -l unique_file "ignore-pr-sync-$ignore_timestamp.txt"
echo content >"$unique_file"
git add "$unique_file"
git commit -m Test >/dev/null 2>&1

# End with --ignore pr
run flo end --yes --ignore pr --resolve success

# Should not sync main (because no PR was touched)
assert_output_not_contains Sync "Does not sync main with --ignore pr"

# Cleanup
cd_temp_repo
git worktree remove --force "$WORKTREE_PATH" 2>/dev/null; or true

# Test 4: Don't sync in abort mode
cd_temp_repo
set -l abort_timestamp (date +%s)
set -l abort_branch "feat/abort-no-sync-$abort_timestamp"
flo "$abort_branch" >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "$abort_branch")
cd "$WORKTREE_PATH"

# Push and create PR
set -l unique_file "abort-no-sync-$abort_timestamp.txt"
echo content >"$unique_file"
git add "$unique_file"
git commit -m Test >/dev/null 2>&1
git push -u origin "$abort_branch" --force >/dev/null 2>&1
gh pr create --title "Abort no sync test $abort_timestamp" --body Test --head "$abort_branch" >/dev/null 2>&1

# End with abort
run flo end --yes --resolve abort

# Should close PR but not sync main
set -l clean_output (strip_ansi "$RUN_OUTPUT")
assert_string_contains "Closed PR" "$clean_output" "Closes PR in abort mode"
assert_output_not_contains Sync "Does not sync main in abort mode"

# Test 5: Sync switches from another branch to main
cd_temp_repo

# Create and switch to a different branch
set -l switch_timestamp (date +%s)
git checkout -b "other-branch-$switch_timestamp" 2>/dev/null

# Create worktree and PR
set -l switch_branch "feat/switch-to-main-$switch_timestamp"
flo "$switch_branch" >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "$switch_branch")
cd "$WORKTREE_PATH"

set -l unique_file "switch-to-main-$switch_timestamp.txt"
echo content >"$unique_file"
git add "$unique_file"
git commit -m Test >/dev/null 2>&1
git push -u origin "$switch_branch" --force >/dev/null 2>&1
gh pr create --title "Switch to main test $switch_timestamp" --body Test --head "$switch_branch" >/dev/null 2>&1

# End (should switch from other-branch to main)
# Use --force to bypass PR check validation (we're testing branch switching)
run flo end --yes --resolve success --force

# Should be on main after operation
cd_temp_repo
set -l CURRENT_BRANCH (git branch --show-current)
assert_string_equals main "$CURRENT_BRANCH" "Switches to main from other branch"

# Cleanup - stay on test-runner, just delete the other branch
git checkout test-runner 2>/dev/null
git branch -D "other-branch-$switch_timestamp" 2>/dev/null

# Test 6: SKIPPED - "Already on main" test is incompatible with gh pr merge
# gh pr merge internally needs to checkout main, which fails if main is already
# checked out in the main repo. The sync behavior is tested in other tests.
