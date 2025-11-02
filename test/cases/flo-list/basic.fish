setup_temp_repo

flo feat/list-test >/dev/null 2>&1

cd_temp_repo
set -l FLO (flo list 2>&1)
assert_string_contains feat-list-test "$FLO" "flo list shows worktree"
