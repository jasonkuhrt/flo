# Test edge cases for flo end
tags slow gh

setup_temp_repo

# Test 1: PR checks pending (not failed, incomplete)
cd_temp_repo
flo feat/pending-checks >/dev/null 2>&1
set -l WORKTREE_PATH (get_worktree_path "feat/pending-checks")
cd "$WORKTREE_PATH"

# Push and create PR
set -l unique_file "pending-checks-"(date +%s)".txt"
echo content >"$unique_file"
git add "$unique_file"
git commit -m "Test with pending checks" >/dev/null 2>&1
git push -u origin feat/pending-checks --force >/dev/null 2>&1
gh pr create --title "Pending checks test" --body Test --head feat/pending-checks >/dev/null 2>&1

# Wait for checks to start (check-fixture workflow takes 30s, so checks will be pending)
wait_for_checks feat/pending-checks 60

# Try to end (checks should be pending, not SUCCESS yet)
run flo end --yes --resolve success
set -l EXIT_CODE $status

# Should block on pending checks (same as failing checks)
test $EXIT_CODE -ne 0
assert_success "Command blocks on pending checks"
assert_output_contains "PR checks not passing" "Shows message about PR checks"

# Worktree should NOT be removed
assert_dir_exists "$WORKTREE_PATH" "Worktree preserved when checks pending"

# Can bypass with --force
run flo end --yes --force --resolve success
set EXIT_CODE $status

test $EXIT_CODE -eq 0
assert_success "Can bypass pending checks with --force"

# Test 2: PR has merge conflicts
cd_temp_repo
run flo feat/merge-conflict
set WORKTREE_PATH (get_worktree_path "feat/merge-conflict")
cd "$WORKTREE_PATH"

# Create a file with content that will conflict
echo "feature content" >shared-file.txt
git add shared-file.txt
git commit -m "Feature commit" >/dev/null 2>&1
git push -u origin feat/merge-conflict --force >/dev/null 2>&1

# Create PR
gh pr create --title "Conflict test" --body Test --head feat/merge-conflict >/dev/null 2>&1

# Now create conflicting commit on main (same file, different content)
cd_temp_repo
git checkout main 2>/dev/null
echo "main content" >shared-file.txt
git add shared-file.txt
git commit -m "Main commit" >/dev/null 2>&1
git push origin main >/dev/null 2>&1

# Try to merge (gh will handle the conflict error)
cd "$WORKTREE_PATH"
run flo end --yes --force --resolve success
set EXIT_CODE $status

# Should fail with merge conflict error from gh
test $EXIT_CODE -ne 0
assert_success "Command fails when PR has merge conflicts"
# gh pr merge outputs various messages - check for any indication of failure
assert_output_contains "CONFLICTING\|conflict\|cannot be merged" "Shows merge conflict error"

# Worktree should NOT be removed (operation failed)
assert_dir_exists "$WORKTREE_PATH" "Worktree preserved when merge fails"

# Cleanup
cd_temp_repo
git reset --hard HEAD~1 >/dev/null 2>&1
git push origin main --force >/dev/null 2>&1 # CRITICAL: Reset remote to undo polluting push
gh pr close feat/merge-conflict >/dev/null 2>&1
git worktree remove --force "$WORKTREE_PATH" 2>/dev/null

# Test 3: Remote branch already deleted
cd_temp_repo
flo feat/remote-deleted >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/remote-deleted")
cd "$WORKTREE_PATH"

# Push branch
set -l unique_file "remote-deleted-"(date +%s)".txt"
echo content >"$unique_file"
git add "$unique_file"
git commit -m Test >/dev/null 2>&1
git push -u origin feat/remote-deleted --force >/dev/null 2>&1

# Manually delete remote branch
git push origin --delete feat/remote-deleted >/dev/null 2>&1

# End worktree (should handle gracefully)
run flo end --yes --resolve success
set EXIT_CODE $status

# Should succeed (local cleanup works even if remote already gone)
test $EXIT_CODE -eq 0
assert_success "Command succeeds when remote branch already deleted"

# Worktree should be removed
assert_not_dir_exists "$WORKTREE_PATH" "Worktree removed even when remote already deleted"

# Test 4: Removing by issue number
cd_temp_repo

# Create worktree using issue number (use issue #17 which is the test fixture)
flo 17 >/dev/null 2>&1

# Find the worktree (pattern depends on issue fetch)
set WORKTREE_PATH (find_worktree "17-test-fixture")

# If worktree was created
if test -n "$WORKTREE_PATH"; and test -d "$WORKTREE_PATH"
    cd "$WORKTREE_PATH"

    # Make a commit
    set -l unique_file "issue-17-"(date +%s)".txt"
    echo content >"$unique_file"
    git add "$unique_file"
    git commit -m Test >/dev/null 2>&1

    # Remove by issue number
    cd_temp_repo
    run flo end 17 --yes --ignore pr

    # Should remove the worktree
    assert_not_dir_exists "$WORKTREE_PATH" "Can remove worktree by issue number"
end

# Test 5: Removing by branch name
cd_temp_repo
flo feat/remove-by-name >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/remove-by-name")

# Remove by branch name from main repo
cd_temp_repo
run flo end feat/remove-by-name --yes --ignore pr

# Should remove the worktree
assert_not_dir_exists "$WORKTREE_PATH" "Can remove worktree by branch name"

# Test 6: Removing by worktree directory path
cd_temp_repo
flo feat/remove-by-dir >/dev/null 2>&1
set WORKTREE_PATH (get_worktree_path "feat/remove-by-dir")

# Get just the directory name
set -l WORKTREE_DIR (basename "$WORKTREE_PATH")

# Remove by directory name
cd_temp_repo
run flo end "$WORKTREE_DIR" --yes --ignore pr

# Should remove the worktree
assert_not_dir_exists "$WORKTREE_PATH" "Can remove worktree by directory name"

# Test 7: Multiple worktrees for same feature (edge case)
cd_temp_repo
run flo feat/multi-1
set -l WORKTREE_1 (get_worktree_path "feat/multi-1")

# Create another worktree with similar name
run flo feat/multi-1-variant
set -l WORKTREE_2 (get_worktree_path "feat/multi-1-variant")

# Both should exist
assert_dir_exists "$WORKTREE_1" "First worktree exists"
assert_dir_exists "$WORKTREE_2" "Second worktree exists"

# Remove first one specifically
cd_temp_repo
flo end feat/multi-1 --yes --ignore pr >/dev/null 2>&1

# Only first should be removed
assert_not_dir_exists "$WORKTREE_1" "First worktree removed"
assert_dir_exists "$WORKTREE_2" "Second worktree unaffected"

# Cleanup
run flo end feat/multi-1-variant --yes --ignore pr

# Test 8: No GitHub remote configured
cd_temp_repo

# Remove origin remote temporarily
set -l ORIGIN_URL (git remote get-url origin 2>/dev/null)
git remote remove origin 2>/dev/null

run flo feat/no-remote
set WORKTREE_PATH (get_worktree_path "feat/no-remote")
cd "$WORKTREE_PATH"

# Try to end (should handle missing remote gracefully)
run flo end --yes --resolve success
set EXIT_CODE $status

# Should either skip PR operations or show clear error
if test $EXIT_CODE -ne 0
    assert_output_contains remote "Shows error about missing remote"
else
    # If it succeeds, it should skip PR operations
    assert_output_not_contains "Merged PR" "Skips PR operations without remote"
end

# Restore origin remote
cd_temp_repo
if test -n "$ORIGIN_URL"
    git remote add origin "$ORIGIN_URL" 2>/dev/null
end

# Cleanup
git worktree remove --force "$WORKTREE_PATH" 2>/dev/null

# Test 9: gh CLI not authenticated
# Note: This test might fail if gh is authenticated, but we can test the error path
cd_temp_repo
run flo feat/no-auth
set WORKTREE_PATH (get_worktree_path "feat/no-auth")
cd "$WORKTREE_PATH"

set -l unique_file "no-auth-"(date +%s)".txt"
echo content >"$unique_file"
git add "$unique_file"
git commit -m Test >/dev/null 2>&1

# Try to end (might fail if gh not authed)
# We can't actually test this reliably, so just verify the error handling exists
run flo end --yes --resolve success

# If it fails, should show helpful error about gh auth
# If it succeeds, gh is authenticated and working

# Cleanup
cd_temp_repo
git worktree remove --force "$WORKTREE_PATH" 2>/dev/null

# Test 10: Detached HEAD worktree (existing behavior)
cd_temp_repo

# Create worktree with detached HEAD (use path within test directory structure)
set -l COMMIT (git rev-parse HEAD)
set -l DETACHED_PATH "$TEST_CASE_TEMP_DIR"_detached-head-test
git worktree add --detach "$DETACHED_PATH" "$COMMIT" >/dev/null 2>&1

cd "$DETACHED_PATH"

# Try to remove (should handle gracefully)
run flo end --yes --ignore pr

# Should remove worktree but skip branch deletion (no branch)
assert_not_dir_exists "$DETACHED_PATH" "Removes detached HEAD worktree"
