#!/bin/bash

# Test subcommand help output

# Test list command help
LIST_HELP=$(flo list --help 2>&1)
assert_snapshot "list-help" "$LIST_HELP"

# Test end command help
END_HELP=$(flo end --help 2>&1)
assert_snapshot "end-help" "$END_HELP"

# Test rm alias help (should show same as end)
RM_HELP=$(flo rm --help 2>&1)
assert_snapshot "rm-help" "$RM_HELP"

# Test prune command help
PRUNE_HELP=$(flo prune --help 2>&1)
assert_snapshot "prune-help" "$PRUNE_HELP"
