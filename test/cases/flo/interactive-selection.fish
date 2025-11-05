tags slow gh

setup_temp_repo
git remote add origin https://github.com/jasonkuhrt/flo.git

# Test: Verify gh can fetch issues and format them correctly
set -l ISSUES_JSON (gh issue list --state open --json number,title --limit 5 2>/dev/null)

assert_success "gh issue list fetches issues successfully"

# Test: Verify issue count logic
set -l ISSUE_COUNT (echo "$ISSUES_JSON" | jq '. | length' 2>/dev/null)

if test -n "$ISSUE_COUNT"; and test "$ISSUE_COUNT" -gt 0
    pass "Issue count extracted correctly (count: $ISSUE_COUNT)"
else
    fail "Failed to extract issue count"
end

# Test: Verify issue formatting for display
set -l FORMATTED (echo "$ISSUES_JSON" | jq -r '.[] | "#\(.number) - \(.title)"' 2>/dev/null | head -1)

if echo "$FORMATTED" | grep -Eq "^#[0-9]+ - "
    pass "Issue formatting works correctly (example: $FORMATTED)"
else
    fail "Issue formatting failed (output: $FORMATTED)"
end

# Test: Verify issue number extraction from formatted string
set -l TEST_STRING "#17 - 🧪 TEST FIXTURE - DO NOT CLOSE 🧪"
set -l EXTRACTED (fish -c "echo '$TEST_STRING' | string replace -r '^#(\d+).*' '\$1'" 2>/dev/null)

assert_string_equals 17 "$EXTRACTED" "Issue number extraction works correctly"

# Test: Verify __flo_select_issue returns non-zero when gum not available
# Create a function wrapper that removes gum from PATH
set -l NO_GUM_RESULT (fish -c "
    function gum; return 127; end
    source $PROJECT_ROOT/functions/flo.fish
    __flo_select_issue
    echo \$status
" 2>/dev/null)

assert_string_equals 1 "$NO_GUM_RESULT" "Function returns error when gum not available"

# Test: Verify full flow with mocked gum (simulates user selecting issue #17)
set -l MOCKED_RESULT (fish -c "
    # Mock gum to return a predetermined selection
    function gum
        if contains -- filter \$argv
            echo '#17 - 🧪 TEST FIXTURE - DO NOT CLOSE 🧪'
        else if contains -- choose \$argv
            echo '#17 - 🧪 TEST FIXTURE - DO NOT CLOSE 🧪'
        end
    end

    source $PROJECT_ROOT/functions/flo.fish
    __flo_select_issue
" 2>/dev/null)

assert_string_equals 17 "$MOCKED_RESULT" "Full flow with mocked gum returns correct issue number"

# Test: Verify function uses gum filter for many issues
set -l USES_FILTER (fish -c "
    # Mock gh to return >10 issues (formatted with template)
    function gh
        if contains -- list \$argv
            echo '#1 - A'
            echo '#2 - B'
            echo '#3 - C'
            echo '#4 - D'
            echo '#5 - E'
            echo '#6 - F'
            echo '#7 - G'
            echo '#8 - H'
            echo '#9 - I'
            echo '#10 - J'
            echo '#11 - K'
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

assert_string_contains FILTER_CALLED "$USES_FILTER" "Uses gum filter for >10 issues"

# Test: Verify function uses gum choose for few issues
set -l USES_CHOOSE (fish -c "
    # Mock gh to return <=10 issues (formatted with template)
    function gh
        if contains -- list \$argv
            echo '#1 - A'
            echo '#2 - B'
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

assert_string_contains CHOOSE_CALLED "$USES_CHOOSE" "Uses gum choose for ≤10 issues"
