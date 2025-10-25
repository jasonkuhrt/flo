#!/bin/bash

setup_temp_repo

flo feat/rm-test >/dev/null 2>&1

flo rm feat/rm-test >/dev/null 2>&1

WORKTREE_PATH=$(get_worktree_path "feat/rm-test")
assert_dir_not_exists "$WORKTREE_PATH" "flo rm removed worktree"
