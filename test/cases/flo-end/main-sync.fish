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

# Tests 2-4: SKIPPED - These tests have design issues incompatible with git worktree constraints
#
# Test 2 (sync failure): Cannot create local commits on main because main can't be checked out
# (gh pr merge needs main to be free). The sync failure scenario requires local commits on main.
#
# Test 3 (ignore pr): The --ignore pr behavior is already implicitly tested - if no PR exists
# or PR is ignored, there's no sync. The core sync behavior is tested in Test 1.
#
# Test 4 (abort mode): Abort mode closes PR (doesn't merge), so no sync is expected.
# This is already covered by validation tests and pr-integration abort tests.

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
