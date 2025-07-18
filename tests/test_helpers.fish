#!/usr/bin/env fish

# Test helpers for flo
# Run with: fishtape tests/*.fish

# Load all flo functions
set -l flo_root (dirname (dirname (status -f)))
source $flo_root/functions/helpers.fish

# Test __flo_validate_issue_number
@test "__flo_validate_issue_number accepts valid numbers" (__flo_validate_issue_number 123) $status -eq 0
@test "__flo_validate_issue_number accepts single digit" (__flo_validate_issue_number 1) $status -eq 0
@test "__flo_validate_issue_number rejects zero" (__flo_validate_issue_number 0) $status -eq 1
@test "__flo_validate_issue_number rejects empty string" (__flo_validate_issue_number "") $status -eq 1
@test "__flo_validate_issue_number rejects letters" (__flo_validate_issue_number "abc") $status -eq 1
@test "__flo_validate_issue_number rejects mixed" (__flo_validate_issue_number "123abc") $status -eq 1

# Test __flo_is_main_branch
@test "__flo_is_main_branch detects main" (__flo_is_main_branch main) $status -eq 0
@test "__flo_is_main_branch detects master" (__flo_is_main_branch master) $status -eq 0
@test "__flo_is_main_branch rejects feature branch" (__flo_is_main_branch feature/123) $status -eq 1
@test "__flo_is_main_branch rejects empty" (__flo_is_main_branch "") $status -eq 1

# Test __flo_generate_branch_name
@test "__flo_generate_branch_name creates valid branch" \
    (__flo_generate_branch_name 123 "Fix bug in parser") = 123-fix-bug-in-parser

@test "__flo_generate_branch_name handles special chars" \
    (__flo_generate_branch_name 456 "Add feature: OAuth 2.0") = 456-add-feature-oauth-2-0

@test "__flo_generate_branch_name fails on invalid issue" \
    (__flo_generate_branch_name "abc" "Title") $status -eq 1

@test "__flo_generate_branch_name fails on empty title" \
    (__flo_generate_branch_name 123 "") $status -eq 1
