setup_temp_repo

run flo feat/list-test

cd_temp_repo
run flo list
assert_output_contains feat-list-test "flo list shows worktree"
