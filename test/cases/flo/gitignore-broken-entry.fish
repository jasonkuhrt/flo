# Test that flo adds correct .gitignore entry even when broken entry exists

setup_temp_repo
git remote add origin https://github.com/jasonkuhrt/flo.git

# Create .gitignore in main repo with broken entry
touch .gitignore
echo "+.claude/*.local.md" >.gitignore
git add .gitignore
git commit -q -m "Add .gitignore with broken entry"

# Create worktree using issue mode
# Helper guarantees .gitignore exists (since main repo has it)
setup_issue_worktree

# Verify flo added correct entry (not just the broken one)
grep -Fxq '.claude/*.local.md' .gitignore 2>/dev/null
assert_success "flo added correct gitignore entry"

# Verify the correct entry actually works for ignoring files
echo test >.claude/CLAUDE.local.md
set -l OUTPUT (git status --porcelain .claude/CLAUDE.local.md 2>&1)

assert_string_equals "" "$OUTPUT" "CLAUDE.local.md properly ignored by git"
