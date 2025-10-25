#!/bin/bash

# Test --project flag path resolution

# Create test project directory
TEMP_BASE=$(mktemp -d)
TEST_PROJECT="$TEMP_BASE/test-flo-project"
mkdir -p "$TEST_PROJECT"
cd "$TEST_PROJECT"
git init -q
git config user.email "test@test.com"
git config user.name "Test"
echo "test" > test.txt
git add test.txt
git commit -q -m "init"

# Normalize path for macOS /var vs /private/var symlink
EXPECTED=$(realpath "$TEST_PROJECT")

# Test 1: Absolute path
RESOLVED=$(fish -c "source $PROJECT_ROOT/functions/flo.fish; __flo_resolve_project_path '$EXPECTED'" 2>&1)

if [[ "$RESOLVED" == "$EXPECTED" ]]; then
    pass "Absolute path resolves correctly"
else
    fail "Absolute path failed (expected: $EXPECTED, got: $RESOLVED)"
fi

# Test 2: Relative path with ./
cd "$TEMP_BASE"
RELATIVE_RESOLVED=$(fish -c "cd $TEMP_BASE; source $PROJECT_ROOT/functions/flo.fish; __flo_resolve_project_path './test-flo-project'" 2>&1)

if [[ "$RELATIVE_RESOLVED" == "$EXPECTED" ]]; then
    pass "Relative path (./) resolves correctly"
else
    fail "Relative path failed (expected: $EXPECTED, got: $RELATIVE_RESOLVED)"
fi

# Test 3: Bare name without settings (should fail with helpful message)
# Temporarily create empty settings
SETTINGS_FILE="$HOME/.config/flo/settings.json"
SETTINGS_BACKUP="$HOME/.config/flo/settings.json.backup-$$"

if [[ -f "$SETTINGS_FILE" ]]; then
    cp "$SETTINGS_FILE" "$SETTINGS_BACKUP"
fi

echo '{}' > "$SETTINGS_FILE"

OUTPUT=$(fish -c "source $PROJECT_ROOT/functions/flo.fish; __flo_resolve_project_path 'backend'" 2>&1)

if echo "$OUTPUT" | grep -q "cannot be resolved"; then
    pass "Bare name without settings shows helpful error"
else
    fail "Should error on bare name without settings"
fi

# Test 4: Name resolution with single match
# Create settings with pattern matching test project
echo "{\"projectsDirectories\": [\"$TEMP_BASE/*\"]}" > "$SETTINGS_FILE"

RESOLVED=$(fish -c "source $PROJECT_ROOT/functions/flo.fish; __flo_resolve_project_path 'test-flo'" 2>&1)

if echo "$RESOLVED" | grep -q "test-flo-project"; then
    pass "Name resolution with single match works"
else
    fail "Name resolution failed (got: $RESOLVED)"
fi

# Test 5: Name resolution with no matches
OUTPUT=$(fish -c "source $PROJECT_ROOT/functions/flo.fish; __flo_resolve_project_path 'nonexistent-xyz'" 2>&1)

if echo "$OUTPUT" | grep -q "not found"; then
    pass "Name resolution shows error for no matches"
else
    fail "Should error on no matches"
fi

# Cleanup: Restore settings
if [[ -f "$SETTINGS_BACKUP" ]]; then
    mv "$SETTINGS_BACKUP" "$SETTINGS_FILE"
else
    rm -f "$SETTINGS_FILE"
fi

# Cleanup test directories
rm -rf "$TEMP_BASE"
