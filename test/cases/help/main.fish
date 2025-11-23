# Test main help output

run flo --help

# Test that help contains expected sections
assert_output_contains flo "Help shows title"
assert_output_contains COMMANDS "Help shows commands section"
assert_output_contains list "Help shows list command"
assert_output_contains rm "Help shows rm command"
assert_output_contains prune "Help shows prune command"

# Snapshot the full help output
assert_snapshot main-help "$RUN_OUTPUT"
