setup_temp_repo
git remote add origin https://github.com/jasonkuhrt/flo.git

# Test: Verify __flo_select_issue function exists and has proper structure
fish -c "source $PROJECT_ROOT/functions/flo.fish; functions -q __flo_select_issue" 2>&1
assert_success "__flo_select_issue function exists"

# Test: Verify function checks for gum and gh dependencies
set -l OUTPUT (fish -c "source $PROJECT_ROOT/functions/flo.fish; functions __flo_select_issue" 2>&1)

assert_string_contains "command -v gum" "$OUTPUT" "Function checks for gum availability"

assert_string_contains "command -v gh" "$OUTPUT" "Function checks for gh CLI availability"

# Test: Verify help is still accessible with flo help
set OUTPUT (fish -c "source $PROJECT_ROOT/functions/flo.fish; flo help" 2>&1)

assert_string_contains "Create worktree from branch or GitHub issue" "$OUTPUT" "flo help shows help message"
