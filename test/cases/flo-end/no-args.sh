#!/bin/bash

setup_temp_repo
git remote add origin https://github.com/jasonkuhrt/flo.git

# Create worktree and cd into it
setup_issue_worktree

WORKTREE_PATH=$(realpath $PWD)

# Test: flo end --force with 'y' confirmation should remove worktree
# (using --force to bypass uncommitted changes check from CLAUDE.local.md)
OUTPUT=$(echo "y" | flo end --force 2>&1)

# Strip ANSI color codes for easier matching
CLEAN_OUTPUT=$(echo "$OUTPUT" | sed 's/\x1b\[[0-9;]*m//g')

if echo "$CLEAN_OUTPUT" | grep -q "Removed worktree"; then
    pass "Worktree removal confirmed in output"
else
    fail "Worktree removal not confirmed (output: $OUTPUT)"
fi

# Verify worktree was actually removed
if [[ ! -d "$WORKTREE_PATH" ]]; then
    pass "Worktree directory removed"
else
    fail "Worktree directory still exists at $WORKTREE_PATH"
fi

# Note: Cannot test pwd change because flo runs in fish subprocess
# The cd command in the fish function cannot affect the bash shell's pwd
