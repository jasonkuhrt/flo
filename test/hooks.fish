# Test hooks for flo
# Define special functions: before_all, before_each, after_each, after_all

function before_all
    # Clean up stale worktrees from previous test runs
    # This prevents flaky tests caused by leftover worktrees in /tmp
    # macOS mktemp creates dirs in /var/folders/xx/yyy/T/, need maxdepth 5
    find /var/folders -maxdepth 5 -name "tmp.*_feat-*" -type d 2>/dev/null | while read -l dir
        rm -rf "$dir" 2>/dev/null
    end
end

function before_each
    # Auto-setup spies for zed and claude to prevent real commands from running
    # Tests can override these spies if they need to make assertions
    spy_on zed
    spy_on claude
end

function after_each
    # Clean up worktrees created by tests
    set -l temp_repo_parent (dirname "$TEST_CASE_TEMP_DIR")
    set -l temp_repo_base (basename "$TEST_CASE_TEMP_DIR")
    cd /tmp 2>/dev/null
    rm -rf "$TEST_CASE_TEMP_DIR" 2>/dev/null
    # Clean up worktree directories - use find to avoid glob issues
    find "$temp_repo_parent" -maxdepth 1 -name "$temp_repo_base"_'*' -type d -exec rm -rf {} + 2>/dev/null
end

# Uncomment to add after_all hook:
# function after_all
#     echo "All tests complete!"
# end
