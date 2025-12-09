setup_temp_repo

# Run flo in branch mode (not issue mode)
flo test-branch >/dev/null 2>&1

set -l WORKTREE_PATH (get_worktree_path "test-branch")

assert_not_file_exists "$WORKTREE_PATH/.claude/CLAUDE.md" \
    "Does not create .claude/CLAUDE.md in branch mode (only for issues)"

# Branch mode also shouldn't create CLAUDE.local.md
assert_not_file_exists "$WORKTREE_PATH/CLAUDE.local.md" \
    "Does not create CLAUDE.local.md in branch mode (only for issues)"
