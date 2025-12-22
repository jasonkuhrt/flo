# Test that flo adds correct .gitignore entry even when broken entry exists

setup_temp_repo
git remote add origin https://github.com/jasonkuhrt/flo-fixture-repo.git

# Create .gitignore in main repo with broken entry (using old path format)
touch .gitignore
echo "+.claude/issue.md" >.gitignore
git add .gitignore
git commit -q -m "Add .gitignore with broken entry"

# Create worktree using issue mode
# Helper guarantees .gitignore exists (since main repo has it)
setup_issue_worktree

# Verify flo added correct entry (not just the broken one)
grep -Fxq '.claude/issue.md' .gitignore 2>/dev/null
assert_success "flo added correct gitignore entry"

# Verify the correct entry actually works for ignoring files
echo test >.claude/issue.md
set -l OUTPUT (git status --porcelain .claude/issue.md 2>&1)

assert_string_equals "" "$OUTPUT" ".claude/issue.md properly ignored by git"
