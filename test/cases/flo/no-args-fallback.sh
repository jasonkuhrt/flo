#!/bin/bash

setup_temp_repo
git remote add origin https://github.com/jasonkuhrt/flo.git

# Test: Verify __flo_select_issue function exists and has proper structure
fish -c "source $PROJECT_ROOT/functions/flo.fish; functions -q __flo_select_issue" 2>&1
if [ $? -eq 0 ]; then
    pass "__flo_select_issue function exists"
else
    fail "__flo_select_issue function not found"
fi

# Test: Verify function checks for gum and gh dependencies
OUTPUT=$(fish -c "source $PROJECT_ROOT/functions/flo.fish; functions __flo_select_issue" 2>&1)

if echo "$OUTPUT" | grep -q "command -v gum"; then
    pass "Function checks for gum availability"
else
    fail "Function doesn't check for gum"
fi

if echo "$OUTPUT" | grep -q "command -v gh"; then
    pass "Function checks for gh CLI availability"
else
    fail "Function doesn't check for gh CLI"
fi

# Test: Verify help is still accessible with flo help
OUTPUT=$(fish -c "source $PROJECT_ROOT/functions/flo.fish; flo help" 2>&1)

if echo "$OUTPUT" | grep -q "Create worktree from branch or GitHub issue"; then
    pass "flo help shows help message"
else
    fail "flo help failed to show help message"
fi
