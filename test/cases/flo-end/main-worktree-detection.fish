# Test that __flo_get_main_worktree correctly identifies main repository

setup_temp_repo
git remote add origin https://github.com/jasonkuhrt/flo-fixture-repo.git

# Get main repo path before creating worktree
set -l MAIN_REPO (realpath $PWD)

# Create a worktree
setup_issue_worktree

# Test 1: From main repo, helper should return main repo
set -l DETECTED_FROM_MAIN (fish -c "cd $MAIN_REPO && source $PROJECT_ROOT/functions/end.fish && __flo_get_main_worktree" 2>&1)

assert_string_equals "$MAIN_REPO" "$DETECTED_FROM_MAIN" "Main worktree detected correctly from main repo"

# Test 2: From worktree, helper should still return main repo
set -l WORKTREE_PATH (realpath $PWD)
set -l DETECTED_FROM_WORKTREE (fish -c "cd $WORKTREE_PATH && source $PROJECT_ROOT/functions/end.fish && __flo_get_main_worktree" 2>&1)

assert_string_equals "$MAIN_REPO" "$DETECTED_FROM_WORKTREE" "Main worktree detected correctly from worktree"

# Test 3: Verify .git structure is as expected
assert_dir_exists "$MAIN_REPO/.git" "Main repo has .git directory"

assert_file_exists "$WORKTREE_PATH/.git" "Worktree has .git file (not directory)"
