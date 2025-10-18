#!/bin/bash

# Test subcommand help output

# Test list command help
LIST_HELP=$(flo list --help 2>&1)
assert_snapshot "list-help" "$LIST_HELP"

# Test rm command help
RM_HELP=$(flo rm --help 2>&1)
assert_snapshot "rm-help" "$RM_HELP"

# Test prune command help
PRUNE_HELP=$(flo prune --help 2>&1)
assert_snapshot "prune-help" "$PRUNE_HELP"
