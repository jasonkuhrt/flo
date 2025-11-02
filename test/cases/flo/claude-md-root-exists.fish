setup_temp_repo
git remote add origin https://github.com/jasonkuhrt/flo.git

# Create root CLAUDE.md to simulate a project with existing configuration
echo "# Project CLAUDE.md" >CLAUDE.md
echo "This is the project's main Claude configuration." >>CLAUDE.md
git add CLAUDE.md
git commit -q -m "Add root CLAUDE.md"

# Run flo in issue mode and cd into the created worktree
setup_issue_worktree

# Main test: .claude/CLAUDE.md should NOT be created when root CLAUDE.md exists
assert_not_file_exists ".claude/CLAUDE.md" \
    "Does not create .claude/CLAUDE.md when root CLAUDE.md exists"

# Verify root CLAUDE.md is present in worktree (Git tracks it)
assert_file_exists "CLAUDE.md"

# Verify CLAUDE.local.md was created (should always be created in issue mode)
assert_file_exists ".claude/CLAUDE.local.md"
