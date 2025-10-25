#!/bin/bash

# Test --yes and -y flags for non-interactive removal

setup_temp_repo

# Test 1: --yes flag (no stdin, removes worktree)
flo feat/yes-test >/dev/null 2>&1
WORKTREE_PATH=$(get_worktree_path "feat/yes-test")

# Enter the worktree
cd "$WORKTREE_PATH"

# Remove with --yes (no stdin provided)
OUTPUT=$(flo end --yes 2>&1)

# Should succeed without prompting
if echo "$OUTPUT" | grep -q "Removed worktree"; then
    pass "--yes flag removes worktree without prompt"
else
    fail "--yes flag did not remove worktree (output: $OUTPUT)"
fi

# Verify worktree was actually removed
if [[ ! -d "$WORKTREE_PATH" ]]; then
    pass "--yes flag: worktree directory removed"
else
    fail "--yes flag: worktree directory still exists at $WORKTREE_PATH"
fi

# Test 2: -y short form
cd_temp_repo
flo feat/short-yes-test >/dev/null 2>&1
WORKTREE_PATH=$(get_worktree_path "feat/short-yes-test")
cd "$WORKTREE_PATH"

OUTPUT=$(flo end -y 2>&1)

if echo "$OUTPUT" | grep -q "Removed worktree"; then
    pass "-y short form works"
else
    fail "-y short form did not work (output: $OUTPUT)"
fi

# Test 3: --yes with --force combined
cd_temp_repo
flo feat/yes-force-test >/dev/null 2>&1
WORKTREE_PATH=$(get_worktree_path "feat/yes-force-test")
cd "$WORKTREE_PATH"

# Create uncommitted change
echo "test" > uncommitted.txt

OUTPUT=$(flo end --yes --force 2>&1)

if echo "$OUTPUT" | grep -q "Removed worktree"; then
    pass "--yes --force combined flags work"
else
    fail "--yes --force did not work (output: $OUTPUT)"
fi

if [[ ! -d "$WORKTREE_PATH" ]]; then
    pass "--yes --force: worktree directory removed"
else
    fail "--yes --force: worktree directory still exists"
fi

# Test 4: --yes with specific worktree (not current directory)
cd_temp_repo
flo feat/specific-yes-test >/dev/null 2>&1

# Remove from main repo (not from within the worktree)
OUTPUT=$(flo end feat/specific-yes-test --yes 2>&1)
WORKTREE_PATH=$(get_worktree_path "feat/specific-yes-test")

# Note: When removing specific worktree (not current), there's no prompt anyway
# But --yes should still work without error
if [[ ! -d "$WORKTREE_PATH" ]]; then
    pass "--yes with specific worktree works"
else
    fail "--yes with specific worktree failed"
fi
