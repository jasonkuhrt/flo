#!/bin/bash

setup_temp_repo
git remote add origin https://github.com/jasonkuhrt/flo.git

# Test: Verify gh can fetch issues and format them correctly
ISSUES_JSON=$(gh issue list --state open --json number,title --limit 5 2>/dev/null)

if [ $? -eq 0 ]; then
    pass "gh issue list fetches issues successfully"
else
    fail "Failed to fetch issues with gh CLI"
fi

# Test: Verify issue count logic
ISSUE_COUNT=$(echo "$ISSUES_JSON" | jq '. | length' 2>/dev/null)

if [ -n "$ISSUE_COUNT" ] && [ "$ISSUE_COUNT" -gt 0 ]; then
    pass "Issue count extracted correctly (count: $ISSUE_COUNT)"
else
    fail "Failed to extract issue count"
fi

# Test: Verify issue formatting for display
FORMATTED=$(echo "$ISSUES_JSON" | jq -r '.[] | "#\(.number) - \(.title)"' 2>/dev/null | head -1)

if echo "$FORMATTED" | grep -Eq "^#[0-9]+ - "; then
    pass "Issue formatting works correctly (example: $FORMATTED)"
else
    fail "Issue formatting failed (output: $FORMATTED)"
fi

# Test: Verify issue number extraction from formatted string
TEST_STRING="#17 - Test Fixture - Do Not Close"
EXTRACTED=$(fish -c "echo '$TEST_STRING' | string replace -r '^#(\d+).*' '\$1'" 2>/dev/null)

if [ "$EXTRACTED" = "17" ]; then
    pass "Issue number extraction works correctly"
else
    fail "Issue number extraction failed (got: $EXTRACTED)"
fi

# Test: Verify __flo_select_issue returns non-zero when gum not available
# Create a function wrapper that removes gum from PATH
NO_GUM_RESULT=$(fish -c "
    function gum; return 127; end
    source $PROJECT_ROOT/functions/flo.fish
    __flo_select_issue
    echo \$status
" 2>/dev/null)

if [ "$NO_GUM_RESULT" = "1" ]; then
    pass "Function returns error when gum not available"
else
    fail "Function should return error without gum (got: $NO_GUM_RESULT)"
fi

# Test: Verify full flow with mocked gum (simulates user selecting issue #17)
MOCKED_RESULT=$(fish -c "
    # Mock gum to return a predetermined selection
    function gum
        if contains -- filter \$argv
            echo '#17 - Test Fixture - Do Not Close'
        else if contains -- choose \$argv
            echo '#17 - Test Fixture - Do Not Close'
        end
    end

    source $PROJECT_ROOT/functions/flo.fish
    __flo_select_issue
" 2>/dev/null)

if [ "$MOCKED_RESULT" = "17" ]; then
    pass "Full flow with mocked gum returns correct issue number"
else
    fail "Mocked gum flow failed (got: $MOCKED_RESULT)"
fi

# Test: Verify function uses gum filter for many issues
USES_FILTER=$(fish -c "
    # Mock gh to return >10 issues
    function gh
        if contains -- list \$argv
            echo '[{\"number\":1,\"title\":\"A\"},{\"number\":2,\"title\":\"B\"},{\"number\":3,\"title\":\"C\"},{\"number\":4,\"title\":\"D\"},{\"number\":5,\"title\":\"E\"},{\"number\":6,\"title\":\"F\"},{\"number\":7,\"title\":\"G\"},{\"number\":8,\"title\":\"H\"},{\"number\":9,\"title\":\"I\"},{\"number\":10,\"title\":\"J\"},{\"number\":11,\"title\":\"K\"}]'
        end
    end

    # Mock gum to detect which command is called
    function gum
        if contains -- filter \$argv
            echo 'FILTER_CALLED'
        else if contains -- choose \$argv
            echo 'CHOOSE_CALLED'
        end
    end

    source $PROJECT_ROOT/functions/flo.fish
    __flo_select_issue 2>&1
" 2>/dev/null)

if echo "$USES_FILTER" | grep -q "FILTER_CALLED"; then
    pass "Uses gum filter for >10 issues"
else
    fail "Should use gum filter for >10 issues (got: $USES_FILTER)"
fi

# Test: Verify function uses gum choose for few issues
USES_CHOOSE=$(fish -c "
    # Mock gh to return <=10 issues
    function gh
        if contains -- list \$argv
            echo '[{\"number\":1,\"title\":\"A\"},{\"number\":2,\"title\":\"B\"}]'
        end
    end

    # Mock gum to detect which command is called
    function gum
        if contains -- filter \$argv
            echo 'FILTER_CALLED'
        else if contains -- choose \$argv
            echo 'CHOOSE_CALLED'
        end
    end

    source $PROJECT_ROOT/functions/flo.fish
    __flo_select_issue 2>&1
" 2>/dev/null)

if echo "$USES_CHOOSE" | grep -q "CHOOSE_CALLED"; then
    pass "Uses gum choose for ≤10 issues"
else
    fail "Should use gum choose for ≤10 issues (got: $USES_CHOOSE)"
fi
