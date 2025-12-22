setup_temp_repo
git remote add origin https://github.com/jasonkuhrt/flo-fixture-repo.git

# Create worktree and cd into it
setup_issue_worktree

set -l WORKTREE_PATH (realpath $PWD)

# Test: flo end --force with 'y' confirmation should remove worktree
# (using --force to bypass uncommitted changes check from .claude/issue.md)
set -l OUTPUT (echo "y" | flo end --force 2>&1)

# Strip ANSI color codes for easier matching
set -l CLEAN_OUTPUT (echo "$OUTPUT" | sed 's/\x1b\[[0-9;]*m//g')

assert_string_contains "Removed worktree" "$CLEAN_OUTPUT" "Worktree removal confirmed in output"

# Verify worktree was actually removed
assert_not_dir_exists "$WORKTREE_PATH" "Worktree directory removed"

# Note: Cannot test pwd change because flo runs in fish subprocess
# The cd command in the fish function cannot affect the bash shell's pwd
