#!/bin/bash

setup_temp_repo

flo prune >/dev/null 2>&1
assert_success "flo prune executed without error"
