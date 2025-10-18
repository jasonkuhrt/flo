#!/bin/bash

setup_temp_repo

flo feat/list-test >/dev/null 2>&1

cd_temp_repo
FLO=$(flo list 2>&1)
assert_output_contains "$FLO" "feat-list-test" "flo list shows worktree"
