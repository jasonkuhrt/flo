#!/bin/bash

setup_temp_repo

# Run flo in branch mode (not issue mode)
flo "test-branch" >/dev/null 2>&1

WORKTREE_PATH=$(get_worktree_path "test-branch")

assert_file_not_exists "$WORKTREE_PATH/.claude/CLAUDE.md" \
    "Does not create .claude/CLAUDE.md in branch mode (only for issues)"

# Branch mode also shouldn't create CLAUDE.local.md
assert_file_not_exists "$WORKTREE_PATH/.claude/CLAUDE.local.md" \
    "Does not create .claude/CLAUDE.local.md in branch mode (only for issues)"
