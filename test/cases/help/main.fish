# Test main help output

set -g HELP (flo --help 2>&1)

# Test that help contains expected sections
assert_string_contains flo "$HELP" "Help shows title"
assert_string_contains COMMANDS "$HELP" "Help shows commands section"
assert_string_contains list "$HELP" "Help shows list command"
assert_string_contains rm "$HELP" "Help shows rm command"
assert_string_contains prune "$HELP" "Help shows prune command"

# Snapshot the full help output
assert_snapshot main-help "$HELP"
