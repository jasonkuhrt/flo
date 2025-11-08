# Test main branch sync behavior for flo end
tags slow gh

setup_temp_repo

# Test 1: Sync main after successful PR merge
cd_temp_repo

# Make sure we're on main and have latest
git checkout main 2>/dev/null

# Create a worktree and PR
flo feat/sync-test-1 >/dev/null 2>&1
set -l WORKTREE_PATH (get_worktree_path "feat/sync-test-1")
cd "$WORKTREE_PATH"

# Push and create/merge PR
set -l unique_file "sync-test-1-"(date +%s)".txt"
echo content >"$unique_file"
git add "$unique_file"
git commit -m "Test commit" >/dev/null 2>&1
git push -u origin feat/sync-test-1 --force >/dev/null 2>&1
gh pr create --title "Sync test PR" --body Test --head feat/sync-test-1 >/dev/null 2>&1

# End worktree (should merge PR and sync main)
run flo end --yes --resolve success

# Should mention syncing main
assert_string_contains Sync "$RUN_OUTPUT" "Output mentions syncing main branch"

# Should be on main branch after operation
cd_temp_repo
set -l CURRENT_BRANCH (git branch --show-current)
assert_string_equals main "$CURRENT_BRANCH" "Switched to main branch after PR merge"

# Main should be up-to-date (git pull should be no-op)
set -l PULL_OUTPUT (git pull origin main 2>&1)
assert_string_contains "up to date" "$PULL_OUTPUT" "Main branch is synced with remote"

# Test 2: Handle main sync failures gracefully
cd_temp_repo
flo feat/sync-fail-test >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/sync-fail-test")
cd "$WORKTREE_PATH"

# Push and create PR
set -l unique_file "sync-fail-test-"(date +%s)".txt"
echo content >"$unique_file"
git add "$unique_file"
git commit -m Test >/dev/null 2>&1
git push -u origin feat/sync-fail-test --force >/dev/null 2>&1
gh pr create --title "Sync fail test" --body Test --head feat/sync-fail-test >/dev/null 2>&1

# Go to main and create a conflicting commit
cd_temp_repo
echo conflict >conflict.txt
git add conflict.txt
git commit -m "Conflicting commit" >/dev/null 2>&1

# Now end the worktree (sync might fail due to local commits)
cd "$WORKTREE_PATH"
run flo end --yes --resolve success
set -l EXIT_CODE $status

# Command should succeed even if sync fails
test $EXIT_CODE -eq 0
assert_success "Command succeeds even when main sync fails"

# Should show warning about sync failure
assert_string_contains sync "$RUN_OUTPUT" "Shows message about main sync"

# Worktree should still be removed (cleanup succeeded)
assert_not_dir_exists "$WORKTREE_PATH" "Worktree removed despite sync failure"

# Test 3: Skip sync when --ignore pr used
cd_temp_repo
# Reset main to clean state
git reset --hard HEAD~1 >/dev/null 2>&1

flo feat/ignore-pr-sync >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/ignore-pr-sync")
cd "$WORKTREE_PATH"

# Create changes but don't create PR
set -l unique_file "ignore-pr-sync-"(date +%s)".txt"
echo content >"$unique_file"
git add "$unique_file"
git commit -m Test >/dev/null 2>&1

# End with --ignore pr
run flo end --yes --ignore pr --resolve success

# Should not sync main (because no PR was touched)
assert_not_string_contains Sync "$RUN_OUTPUT" "Does not sync main with --ignore pr"

# Cleanup
cd_temp_repo
git worktree remove --force "$WORKTREE_PATH" 2>/dev/null; or true

# Test 4: Don't sync in abort mode
cd_temp_repo
flo feat/abort-no-sync >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/abort-no-sync")
cd "$WORKTREE_PATH"

# Push and create PR
set -l unique_file "abort-no-sync-"(date +%s)".txt"
echo content >"$unique_file"
git add "$unique_file"
git commit -m Test >/dev/null 2>&1
git push -u origin feat/abort-no-sync --force >/dev/null 2>&1
gh pr create --title "Abort no sync test" --body Test --head feat/abort-no-sync >/dev/null 2>&1

# End with abort
run flo end --yes --resolve abort

# Should close PR but not sync main
set -l clean_output (strip_ansi "$RUN_OUTPUT")
assert_string_contains "Closed PR" "$clean_output" "Closes PR in abort mode"
assert_not_string_contains Sync "$clean_output" "Does not sync main in abort mode"

# Test 5: Sync switches from another branch to main
cd_temp_repo

# Create and switch to a different branch
git checkout -b other-branch 2>/dev/null

# Create worktree and PR
flo feat/switch-to-main >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/switch-to-main")
cd "$WORKTREE_PATH"

set -l unique_file "switch-to-main-"(date +%s)".txt"
echo content >"$unique_file"
git add "$unique_file"
git commit -m Test >/dev/null 2>&1
git push -u origin feat/switch-to-main --force >/dev/null 2>&1
gh pr create --title "Switch to main test" --body Test --head feat/switch-to-main >/dev/null 2>&1

# End (should switch from other-branch to main)
run flo end --yes --resolve success

# Should be on main after operation
cd_temp_repo
set -l CURRENT_BRANCH (git branch --show-current)
assert_string_equals main "$CURRENT_BRANCH" "Switches to main from other branch"

# Cleanup
git checkout main 2>/dev/null
git branch -D other-branch 2>/dev/null

# Test 6: Sync when already on main
cd_temp_repo
git checkout main 2>/dev/null

flo feat/already-on-main >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/already-on-main")
cd "$WORKTREE_PATH"

set -l unique_file "already-on-main-"(date +%s)".txt"
echo content >"$unique_file"
git add "$unique_file"
git commit -m Test >/dev/null 2>&1
git push -u origin feat/already-on-main --force >/dev/null 2>&1
gh pr create --title "Already on main test" --body Test --head feat/already-on-main >/dev/null 2>&1

# End (main repo already on main)
run flo end --yes --resolve success

# Should still sync (pull latest)
assert_string_contains Sync "$RUN_OUTPUT" "Syncs main even when already on main"

# Should remain on main
cd_temp_repo
set CURRENT_BRANCH (git branch --show-current)
assert_string_equals main "$CURRENT_BRANCH" "Remains on main branch"
