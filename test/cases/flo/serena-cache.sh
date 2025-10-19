#!/bin/bash

setup_temp_repo

# Create mock Serena cache in source repo
mkdir -p .serena/cache
echo "test-cache-data" > .serena/cache/test-file.txt
echo '{"indexed": true}' > .serena/cache/symbols.json

# Create worktree
FLO=$(flo feat/test-serena-cache 2>&1)
WORKTREE_PATH=$(get_worktree_path "feat/test-serena-cache")

# Verify cache was copied to worktree
assert_file_exists "$WORKTREE_PATH/.serena/cache/test-file.txt"
assert_file_exists "$WORKTREE_PATH/.serena/cache/symbols.json"

# Verify file contents match
assert_file_contains "$WORKTREE_PATH/.serena/cache/test-file.txt" "test-cache-data" "Serena cache file content matches"

# Verify user feedback in output
assert_output_contains "$FLO" "Copying Serena cache" "flo output mentions cache copying"
assert_output_contains "$FLO" "Serena cache copied" "flo output confirms cache copied"
