#!/bin/bash

# Test main help output

HELP=$(flo --help 2>&1)

# Test that help contains expected sections
assert_output_contains "$HELP" "flo" "Help shows title"
assert_output_contains "$HELP" "COMMANDS" "Help shows commands section"
assert_output_contains "$HELP" "list" "Help shows list command"
assert_output_contains "$HELP" "rm" "Help shows rm command"
assert_output_contains "$HELP" "prune" "Help shows prune command"

# Snapshot the full help output
assert_snapshot "main-help" "$HELP"
