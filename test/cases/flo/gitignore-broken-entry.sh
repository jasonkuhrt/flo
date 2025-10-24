#!/bin/bash

setup_temp_repo
git remote add origin https://github.com/jasonkuhrt/flo.git

# Create .gitignore in the main repo first (empty, will be in worktree)
touch .gitignore
git add .gitignore
git commit -q -m "Add .gitignore file"

# Add broken gitignore entry (with + prefix - invalid syntax)
echo "+.claude/*.local.md" >> .gitignore
git add .gitignore
git commit -q -m "Add broken gitignore entry"

setup_issue_worktree

# Should add correct entry even though broken entry exists
if grep -Fxq '.claude/*.local.md' .gitignore; then
    pass "Added correct gitignore entry (exact match)"
else
    fail "Did not add correct .claude/*.local.md entry to .gitignore"
fi

# Create the file that should be ignored
echo "test content" > .claude/CLAUDE.local.md

# Verify file is actually ignored by git
OUTPUT=$(git status --porcelain .claude/CLAUDE.local.md 2>&1)

if [[ -z "$OUTPUT" ]]; then
    pass "CLAUDE.local.md is properly ignored by git"
else
    fail "CLAUDE.local.md is NOT ignored by git (git status shows: $OUTPUT)"
fi
