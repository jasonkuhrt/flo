# Test --project flag path resolution

# Create test project directory
set -l TEMP_BASE (mktemp -d)
set -l TEST_PROJECT "$TEMP_BASE/test-flo-project"
mkdir -p "$TEST_PROJECT"
cd "$TEST_PROJECT"
git init -q
git config user.email "test@test.com"
git config user.name Test
echo test >test.txt
git add test.txt
git commit -q -m init

# Normalize path for macOS /var vs /private/var symlink
set -l EXPECTED (realpath "$TEST_PROJECT")

# Test 1: Absolute path
set -l RESOLVED (fish -c "source $PROJECT_ROOT/functions/flo.fish; __flo_resolve_project_path '$EXPECTED'" 2>&1)

assert_string_equals "$EXPECTED" "$RESOLVED" "Absolute path resolves correctly"

# Test 2: Relative path with ./
cd "$TEMP_BASE"
set -l RELATIVE_RESOLVED (fish -c "cd $TEMP_BASE; source $PROJECT_ROOT/functions/flo.fish; __flo_resolve_project_path './test-flo-project'" 2>&1)

assert_string_equals "$EXPECTED" "$RELATIVE_RESOLVED" "Relative path (./) resolves correctly"

# Test 3: Bare name without settings (should fail with helpful message)
# Temporarily create empty settings
set -l SETTINGS_FILE "$HOME/.config/flo/settings.json"
set -l SETTINGS_BACKUP "$HOME/.config/flo/settings.json.backup-$fish_pid"

if test -f "$SETTINGS_FILE"
    cp "$SETTINGS_FILE" "$SETTINGS_BACKUP"
end

echo '{}' >"$SETTINGS_FILE"

set -l OUTPUT (fish -c "source $PROJECT_ROOT/functions/flo.fish; __flo_resolve_project_path 'backend'" 2>&1)

assert_string_contains "cannot be resolved" "$OUTPUT" "Bare name without settings shows helpful error"

# Test 4: Name resolution with single match
# Create settings with pattern matching test project
echo "{\"projectsDirectories\": [\"$TEMP_BASE/*\"]}" >"$SETTINGS_FILE"

set RESOLVED (fish -c "source $PROJECT_ROOT/functions/flo.fish; __flo_resolve_project_path 'test-flo'" 2>&1)

assert_string_contains test-flo-project "$RESOLVED" "Name resolution with single match works"

# Test 5: Name resolution with no matches
set OUTPUT (fish -c "source $PROJECT_ROOT/functions/flo.fish; __flo_resolve_project_path 'nonexistent-xyz'" 2>&1)

assert_string_contains "not found" "$OUTPUT" "Name resolution shows error for no matches"

# Cleanup: Restore settings
if test -f "$SETTINGS_BACKUP"
    mv "$SETTINGS_BACKUP" "$SETTINGS_FILE"
else
    rm -f "$SETTINGS_FILE"
end

# Cleanup test directories
rm -rf "$TEMP_BASE"
