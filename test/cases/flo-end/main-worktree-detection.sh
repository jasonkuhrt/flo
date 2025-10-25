#!/bin/bash

# Test that __flo_get_main_worktree correctly identifies main repository

setup_temp_repo
git remote add origin https://github.com/jasonkuhrt/flo.git

# Get main repo path before creating worktree
MAIN_REPO=$(realpath $PWD)

# Create a worktree
setup_issue_worktree

# Test 1: From main repo, helper should return main repo
DETECTED_FROM_MAIN=$(fish -c "cd $MAIN_REPO && source $PROJECT_ROOT/functions/end.fish && __flo_get_main_worktree" 2>&1)

if [[ "$DETECTED_FROM_MAIN" == "$MAIN_REPO" ]]; then
    pass "Main worktree detected correctly from main repo"
else
    fail "Failed from main repo (expected: $MAIN_REPO, got: $DETECTED_FROM_MAIN)"
fi

# Test 2: From worktree, helper should still return main repo
WORKTREE_PATH=$(realpath $PWD)
DETECTED_FROM_WORKTREE=$(fish -c "cd $WORKTREE_PATH && source $PROJECT_ROOT/functions/end.fish && __flo_get_main_worktree" 2>&1)

if [[ "$DETECTED_FROM_WORKTREE" == "$MAIN_REPO" ]]; then
    pass "Main worktree detected correctly from worktree"
else
    fail "Failed from worktree (expected: $MAIN_REPO, got: $DETECTED_FROM_WORKTREE)"
fi

# Test 3: Verify .git structure is as expected
if [[ -d "$MAIN_REPO/.git" ]]; then
    pass "Main repo has .git directory"
else
    fail "Main repo should have .git directory"
fi

if [[ -f "$WORKTREE_PATH/.git" ]]; then
    pass "Worktree has .git file (not directory)"
else
    fail "Worktree should have .git file pointing to main"
fi
