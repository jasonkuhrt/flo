#!/bin/bash

# Test branch deletion behavior when removing worktrees

setup_temp_repo

# Test 1: Default behavior - branch should be deleted
flo feat/delete-test >/dev/null 2>&1
WORKTREE_PATH=$(get_worktree_path "feat/delete-test")
cd "$WORKTREE_PATH"

# Verify branch exists before removal
if git branch | grep -q "feat/delete-test"; then
    pass "Branch feat/delete-test exists before removal"
else
    fail "Branch feat/delete-test should exist before removal"
fi

# Remove worktree (should also delete branch)
OUTPUT=$(flo end --yes 2>&1)

# Check output mentions branch deletion
if echo "$OUTPUT" | grep -q "Deleted branch"; then
    pass "Output confirms branch deletion"
else
    fail "Output should confirm branch deletion (output: $OUTPUT)"
fi

# Verify branch no longer exists
if ! git branch | grep -q "feat/delete-test"; then
    pass "Branch feat/delete-test deleted after removal"
else
    fail "Branch feat/delete-test should be deleted"
fi

# Test 2: --keep-branch flag preserves the branch
cd_temp_repo
flo feat/keep-test >/dev/null 2>&1
WORKTREE_PATH=$(get_worktree_path "feat/keep-test")
cd "$WORKTREE_PATH"

OUTPUT=$(flo end --yes --keep-branch 2>&1)

# Check output confirms keeping branch
if echo "$OUTPUT" | grep -q "Kept branch"; then
    pass "--keep-branch: Output confirms branch kept"
else
    fail "--keep-branch: Output should confirm branch kept (output: $OUTPUT)"
fi

# Return to main repo to check branch
cd_temp_repo

# Verify branch still exists
if git branch | grep -q "feat/keep-test"; then
    pass "--keep-branch: Branch still exists after removal"
else
    fail "--keep-branch: Branch should still exist"
fi

# Cleanup
git branch -d feat/keep-test >/dev/null 2>&1

# Test 3: Remove by branch name (not from within worktree)
cd_temp_repo
flo feat/remote-delete >/dev/null 2>&1

# Remove from main repo
flo end feat/remote-delete --yes >/dev/null 2>&1

# Verify branch was deleted
if ! git branch | grep -q "feat/remote-delete"; then
    pass "Branch deleted when removing by name"
else
    fail "Branch should be deleted when removing by name"
fi

# Test 4: -k short form works
cd_temp_repo
flo feat/short-keep >/dev/null 2>&1
WORKTREE_PATH=$(get_worktree_path "feat/short-keep")
cd "$WORKTREE_PATH"

flo end --yes -k >/dev/null 2>&1

# Return to main repo to check branch
cd_temp_repo

if git branch | grep -q "feat/short-keep"; then
    pass "-k short form preserves branch"
else
    fail "-k short form should preserve branch"
fi

# Cleanup
git branch -d feat/short-keep >/dev/null 2>&1

# Test 5: Force delete unmerged branch
cd_temp_repo
flo feat/unmerged-test >/dev/null 2>&1
WORKTREE_PATH=$(get_worktree_path "feat/unmerged-test")
cd "$WORKTREE_PATH"

# Create a commit that's not in main
echo "unmerged content" > unmerged.txt
git add unmerged.txt
git commit -m "Unmerged commit" >/dev/null 2>&1

# Try to remove without --force (git branch -d should fail, but log error)
cd_temp_repo
OUTPUT=$(flo end feat/unmerged-test --yes 2>&1)

# Branch deletion should fail with helpful error
if echo "$OUTPUT" | grep -q "Failed to delete branch"; then
    pass "Unmerged branch: Shows error message"
else
    fail "Unmerged branch: Should show error message (output: $OUTPUT)"
fi

# Branch should still exist (deletion failed)
if git branch | grep -q "feat/unmerged-test"; then
    pass "Unmerged branch: Branch still exists after failed deletion"
else
    fail "Unmerged branch: Branch should still exist"
fi

# Now force delete it
flo feat/unmerged-test >/dev/null 2>&1
WORKTREE_PATH=$(get_worktree_path "feat/unmerged-test")
cd "$WORKTREE_PATH"

OUTPUT=$(flo end --yes --force 2>&1)

# With --force, branch should be deleted
if echo "$OUTPUT" | grep -q "Deleted branch"; then
    pass "--force: Force-deletes unmerged branch"
else
    fail "--force: Should force-delete unmerged branch (output: $OUTPUT)"
fi

if ! git branch | grep -q "feat/unmerged-test"; then
    pass "--force: Unmerged branch deleted"
else
    fail "--force: Unmerged branch should be deleted"
fi
