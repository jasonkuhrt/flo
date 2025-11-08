# Test subcommand help output

# Test list command help
run flo list --help
assert_snapshot list-help "$RUN_OUTPUT"

# Test end command help
run flo end --help
assert_snapshot end-help "$RUN_OUTPUT"

# Test rm alias help (should show same as end)
run flo rm --help
assert_snapshot rm-help "$RUN_OUTPUT"

# Test prune command help
run flo prune --help
assert_snapshot prune-help "$RUN_OUTPUT"
