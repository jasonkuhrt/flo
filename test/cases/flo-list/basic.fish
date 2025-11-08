setup_temp_repo

run flo feat/list-test

cd_temp_repo
run flo list
assert_string_contains feat-list-test "$RUN_OUTPUT" "flo list shows worktree"
