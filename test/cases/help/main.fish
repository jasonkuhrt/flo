# Test main help output

run flo --help

# Test that help contains expected sections
assert_string_contains flo "$RUN_OUTPUT" "Help shows title"
assert_string_contains COMMANDS "$RUN_OUTPUT" "Help shows commands section"
assert_string_contains list "$RUN_OUTPUT" "Help shows list command"
assert_string_contains rm "$RUN_OUTPUT" "Help shows rm command"
assert_string_contains prune "$RUN_OUTPUT" "Help shows prune command"

# Snapshot the full help output
assert_snapshot main-help "$RUN_OUTPUT"
