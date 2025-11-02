setup_temp_repo
git remote add origin https://github.com/jasonkuhrt/flo.git

# Test: flo start with issue number (explicit command syntax)
flo start 17 >/dev/null 2>&1

# Find the created worktree
set -l WORKTREE_PATH (find_worktree "17-test-fixture")

if test -z "$WORKTREE_PATH"
    fail "flo start did not create worktree for issue #17"
    exit 1
end

# Verify worktree directory exists
assert_dir_exists "$WORKTREE_PATH" "flo start created worktree from issue number"

# Verify branch was created with correct pattern (feat/17-...)
git show-ref --verify --quiet refs/heads/feat/17-test-fixture-do-not-close
assert_success "flo start created branch from issue"

# Verify Claude context was created (issue mode)
assert_file_exists "$WORKTREE_PATH/.claude/CLAUDE.local.md" "flo start created Claude context for issue"
