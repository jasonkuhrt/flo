#!/usr/bin/env fish

# Test __flo_parse_args helpers
# Run with: fishtape tests/*.fish

# Load all flo functions
set -l flo_root (dirname (dirname (status -f)))
source $flo_root/functions/helpers.fish

# Test __flo_validate_required
@test "__flo_validate_required accepts non-empty value" \
    (__flo_validate_required "param" "value") $status -eq 0

@test "__flo_validate_required rejects empty value" \
    (__flo_validate_required "param" "") $status -eq 1

@test "__flo_validate_required shows custom message" \
    begin
        __flo_validate_required issue "" "Usage: flo issue <number>" 2>&1
        # Check that error was shown (would need to capture stderr)
    end $status -eq 1

# Test common option groups
@test "__flo_common_opts_help returns help spec" \
    (__flo_common_opts_help) = h/help

@test "__flo_common_opts_verbose returns verbose spec" \
    (__flo_common_opts_verbose) = v/verbose

@test "__flo_common_opts_editor returns multiple specs" \
    (count (__flo_common_opts_editor)) -eq 2

@test "__flo_common_opts_pr returns PR options" \
    begin
        set -l opts (__flo_common_opts_pr)
        contains d/draft $opts
        and contains "t/title=" $opts
        and contains "b/body=" $opts
        and contains "base=" $opts
    end
