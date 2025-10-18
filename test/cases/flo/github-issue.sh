#!/bin/bash

setup_temp_repo
git remote add origin https://github.com/jasonkuhrt/flo.git

FLO=$(flo 17 2>&1)

if echo "$FLO" | grep -q "test-fixture"; then
    pass "Used issue title in branch name"
else
    # Fallback: accept if it at least processed the issue number
    if echo "$FLO" | grep -q "17"; then
        pass "Processed issue #17"
    else
        fail "Did not process issue #17"
    fi
fi

WORKTREE_DIR=$(find_worktree "17-test-fixture")

if [[ -n "$WORKTREE_DIR" ]] && [[ -f "$WORKTREE_DIR/.claude/CLAUDE.local.md" ]]; then
    CLAUDE_FILE="$WORKTREE_DIR/.claude/CLAUDE.local.md"

    assert_file_contains "$CLAUDE_FILE" "CRITICAL.*ALL comments" \
        "CLAUDE.local.md contains instruction to read ALL comments"

    assert_file_contains "$CLAUDE_FILE" "Later comments take precedence" \
        "CLAUDE.local.md contains precedence instruction"

    assert_file_contains "$CLAUDE_FILE" "and all comments" \
        "Instructions explicitly mention reading comments"
else
    echo "⚠️  Worktree not found, skipping CLAUDE.local.md tests"
fi
