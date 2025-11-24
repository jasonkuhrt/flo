# Source shared libraries
set -l flo_dir (dirname (status --current-filename))
source "$flo_dir/__flo_lib_log.fish"

# Helper to get main worktree directory
function __flo_get_main_worktree --description "Get path to main repository (shared .git directory)"
    # Uses git-common-dir to reliably find main repository
    #
    # Why this works:
    # - Main repo has actual .git/ directory
    # - Worktrees have .git file pointing to .git/worktrees/<name>/
    # - git-common-dir returns the shared .git location (always in main repo)
    # - Parent of .git-common-dir is the main repository directory
    #
    # Why not use "first in git worktree list"?
    # - While first-in-list is reliable, git-common-dir is more semantic
    # - Directly asks Git "where is the shared .git?"
    # - More explicit about what we're looking for
    # - Works even if worktree list behavior changes
    #
    # Example:
    #   Main:     /projects/kit/.git                    (directory)
    #   Worktree: /projects/kit_feat/.git               (file pointing to main)
    #
    #   From either location:
    #   git rev-parse --git-common-dir → /projects/kit/.git
    #   Parent of that → /projects/kit (main repo!)

    set -l git_common_dir (git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)

    if test $status -ne 0; or test -z "$git_common_dir"
        # Not in a git repo or command failed
        return 1
    end

    # Main repo is parent of .git-common-dir
    set -l main_repo (dirname "$git_common_dir")

    # Verify it's actually a directory
    if test -d "$main_repo"
        echo "$main_repo"
        return 0
    else
        return 1
    end
end

# Helper function to delete a branch after removing worktree
function __flo_delete_branch --description "Delete a git branch with appropriate flags"
    set -l branch_name $argv[1]
    set -l force_delete $argv[2] # "true" if --force flag was provided

    if test -z "$branch_name"
        return 0
    end

    # Choose deletion flag based on force mode
    set -l delete_flag -d
    if test "$force_delete" = true
        set delete_flag -D
    end

    # Attempt to delete the branch
    if git branch $delete_flag "$branch_name" 2>/dev/null
        __flo_log_success "Deleted local branch: $branch_name"
        return 0
    else
        # Branch deletion failed
        if test "$delete_flag" = -d
            __flo_log_error "Failed to delete branch: $branch_name" "Branch has unmerged changes. Use --force to force delete"
        else
            __flo_log_error "Failed to delete branch: $branch_name"
        end
        return 1
    end
end

# Check if gh CLI is available
function __flo_check_gh --description "Check if gh CLI is installed and authenticated"
    if not command -q gh
        __flo_log_error "GitHub CLI (gh) not found" "Install with: brew install gh"
        return 1
    end

    if not gh auth status >/dev/null 2>&1
        __flo_log_error "GitHub CLI not authenticated" "Run: gh auth login"
        return 1
    end

    return 0
end

# Get PR number for a branch
function __flo_get_pr_number --description "Get PR number for a branch"
    set -l branch_name $argv[1]

    if test -z "$branch_name"
        return 1
    end

    # Try to get PR number from gh
    set -l pr_number (gh pr view "$branch_name" --json number --jq .number 2>/dev/null)

    if test $status -eq 0; and test -n "$pr_number"
        echo "$pr_number"
        return 0
    else
        return 1
    end
end

# Check if PR checks are passing
function __flo_check_pr_status --description "Check if PR checks are passing"
    set -l branch_name $argv[1]

    if test -z "$branch_name"
        return 1
    end

    # Get PR status checks
    # Note: CheckRun uses "conclusion", StatusContext uses "state"
    set -l check_status (gh pr view "$branch_name" --json statusCheckRollup --jq '.statusCheckRollup[] | (.conclusion // .state)' 2>/dev/null)

    if test $status -ne 0
        # PR not found or gh failed
        return 1
    end

    # Check if all checks are passing (SUCCESS, SKIPPED, or NEUTRAL are acceptable)
    for status_line in $check_status
        switch "$status_line"
            case SUCCESS SKIPPED NEUTRAL
                # These states are acceptable
            case '*'
                # Any other state (FAILURE, PENDING, ERROR, etc.) means not passing
                return 1
        end
    end

    return 0
end

# Validate worktree is clean
function __flo_validate_clean_worktree --description "Check if worktree has no uncommitted changes"
    set -l worktree_path $argv[1]

    # Save current directory
    set -l prev_dir (pwd)

    # Change to worktree
    cd "$worktree_path" || return 1

    # Check for uncommitted changes
    set -l status_output (git status --porcelain 2>/dev/null)

    # Restore directory
    cd "$prev_dir"

    if test -n "$status_output"
        return 1
    end

    return 0
end

# Validate branch is synced (no unpushed commits)
function __flo_validate_branch_synced --description "Check if branch has no unpushed commits"
    set -l worktree_path $argv[1]

    # Save current directory
    set -l prev_dir (pwd)

    # Change to worktree
    cd "$worktree_path" || return 1

    # Check for unpushed commits
    set -l unpushed (git rev-list @{u}..HEAD 2>/dev/null | wc -l | string trim)

    # Restore directory
    cd "$prev_dir"

    if test $status -ne 0
        # No upstream branch configured
        return 0
    end

    if test "$unpushed" -gt 0
        return 1
    end

    return 0
end

# Merge PR
function __flo_merge_pr --description "Merge PR and optionally delete remote branch"
    set -l branch_name $argv[1]
    set -l delete_branch $argv[2] # "true" or "false"

    if test -z "$branch_name"
        return 1
    end

    # Default to deleting branch if not specified
    if test -z "$delete_branch"
        set delete_branch true
    end

    # Check if PR exists
    set -l pr_number (__flo_get_pr_number "$branch_name")

    if test $status -ne 0
        # No PR found - not an error, just skip
        __flo_log_info_dim "No PR found for branch: $branch_name"
        return 0
    end

    # Check if PR is already merged
    set -l pr_state (gh pr view "$branch_name" --json state --jq .state 2>/dev/null)

    if test "$pr_state" = MERGED
        __flo_log_info_dim "PR #$pr_number already merged (idempotent)"
        return 0
    end

    # Merge PR with squash, optionally delete remote branch
    __flo_log_info "Merging PR #$pr_number..."

    if test "$delete_branch" = true
        gh pr merge "$branch_name" --squash --delete-branch 2>&1
    else
        gh pr merge "$branch_name" --squash 2>&1
    end

    if test $status -eq 0
        __flo_log_success "Merged PR #$pr_number"
        return 0
    else
        __flo_log_error "Failed to merge PR #$pr_number" "Check PR status on GitHub"
        return 1
    end
end

# Close PR without merging
function __flo_close_pr --description "Close PR without merging"
    set -l branch_name $argv[1]

    if test -z "$branch_name"
        return 1
    end

    # Check if PR exists
    set -l pr_number (__flo_get_pr_number "$branch_name")

    if test $status -ne 0
        # No PR found - not an error, just skip
        __flo_log_info_dim "No PR found for branch: $branch_name"
        return 0
    end

    # Check if PR is already closed
    set -l pr_state (gh pr view "$branch_name" --json state --jq .state 2>/dev/null)

    if test "$pr_state" = CLOSED
        __flo_log_info_dim "PR #$pr_number already closed (idempotent)"
        return 0
    end

    # Close PR
    __flo_log_info "Closing PR #$pr_number..."

    gh pr close "$branch_name" 2>&1
    if test $status -eq 0
        __flo_log_success "Closed PR #$pr_number"
        return 0
    else
        __flo_log_error "Failed to close PR #$pr_number" "Check PR status on GitHub"
        return 1
    end
end

# Sync main branch
function __flo_sync_main --description "Sync main branch with remote"
    set -l main_worktree $argv[1]

    if test -z "$main_worktree"; or not test -d "$main_worktree"
        return 1
    end

    # Save current directory
    set -l prev_dir (pwd)

    # Change to main worktree
    cd "$main_worktree" || return 1

    # Get current branch
    set -l current_branch (git branch --show-current 2>/dev/null)

    # Checkout main if not already on it
    if test "$current_branch" != main
        __flo_log_info "Switching to main branch..."
        git checkout main >/dev/null 2>&1

        if test $status -ne 0
            cd "$prev_dir"
            __flo_log_warn "Failed to switch to main branch"
            return 1
        end
    end

    # Pull latest changes
    __flo_log_info "Syncing main branch with remote..."

    if git pull origin main >/dev/null 2>&1
        __flo_log_success "Main branch synced"
        return 0
    else
        cd "$prev_dir"
        __flo_log_warn "Failed to sync main branch" "You may need to pull manually"
        return 1
    end
end

function flo_end
    # Parse flags
    argparse f/force y/yes dry 'resolve=' 'ignore=+' 'project=' -- $argv; or return

    # Validate --resolve flag
    set -l resolve_mode success
    if set -q _flag_resolve
        set resolve_mode $_flag_resolve
        if test "$resolve_mode" != success -a "$resolve_mode" != abort
            __flo_log_error "Invalid --resolve value: $resolve_mode" "Must be 'success' or 'abort'"
            return 1
        end
    end

    # Parse --ignore flags (can be multiple)
    set -l ignore_pr false
    set -l ignore_worktree false
    if set -q _flag_ignore
        for ignore_value in $_flag_ignore
            if test "$ignore_value" = pr
                set ignore_pr true
            else if test "$ignore_value" = worktree
                set ignore_worktree true
            else
                __flo_log_error "Invalid --ignore value: $ignore_value" "Must be 'pr' or 'worktree'"
                return 1
            end
        end
    end

    # Exit early if both operations ignored
    if test "$ignore_pr" = true -a "$ignore_worktree" = true
        __flo_log_info "All operations ignored (--ignore pr --ignore worktree)"
        return 0
    end

    # Resolve project path if --project provided
    set -l project_path (pwd)
    if set -q _flag_project
        set project_path (__flo_resolve_project_path "$_flag_project")
        if test $status -ne 0
            # Error already printed by resolver
            return 1
        end
        cd "$project_path" || return 1
    end

    # If we're in a flo worktree and removing by branch name, cd to main worktree first
    # This ensures current_dir is calculated from main repo, not from worktree
    # (Otherwise path calculation doubles the branch name)
    set -l current_path (realpath (pwd))
    set -l current_basename (basename $current_path)

    # Only do this check if an argument is provided (removing by name, not current worktree)
    if test (count $argv) -gt 0
        if string match -qr _ -- $current_basename
            # Looks like a flo worktree - verify with git and get main worktree
            set -l main_worktree (git worktree list --porcelain 2>/dev/null | grep "^worktree" | head -1 | string replace "worktree " "")

            if test -n "$main_worktree"; and test -d "$main_worktree"
                # We're in a git worktree and found the main worktree
                if test "$current_path" != "$main_worktree"
                    # We're not in the main worktree, cd to it
                    cd "$main_worktree" || return 1
                    set project_path "$main_worktree"
                end
            end
        end
    end

    set current_dir (basename $project_path)
    set -l arg $argv[1]

    # Determine worktree path and branch name
    set -l worktree_path ""
    set -l branch_name ""

    # No arguments provided - try to remove current worktree
    if test -z "$arg"
        set current_path (realpath (pwd))

        # Check if current directory looks like a worktree (contains _)
        if not string match -qr _ -- (basename $current_path)
            __flo_log_error "Not in a flo worktree" "Run 'flo end <branch>' to remove a specific worktree"
            return 1
        end

        # Verify it's actually a worktree using git
        set -l worktree_list (git worktree list --porcelain 2>/dev/null)
        set -l is_worktree false
        set -l found_current false

        for line in $worktree_list
            # Check if this line is a worktree path line
            if string match -q "worktree *" -- $line
                set -l wt_path (string replace "worktree " "" -- $line)
                if test "$wt_path" = "$current_path"
                    set found_current true
                    set is_worktree true
                else
                    set found_current false
                end
                # If we found our worktree, capture the branch name
            else if test "$found_current" = true; and string match -q "branch *" -- $line
                set branch_name (string replace "branch refs/heads/" "" -- $line)
                break
            end
        end

        if test "$is_worktree" = false
            __flo_log_error "Not in a flo worktree" "Run 'flo end <branch>' to remove a specific worktree"
            return 1
        end

        set worktree_path $current_path
    else
        # Strip leading # if present (e.g., #123 -> 123)
        set arg (string replace -r '^#' '' -- $arg)

        # Check if argument is an issue number (integer)
        if string match -qr '^\d+$' -- $arg
            # Find worktree matching the issue number pattern
            # Issue worktrees are named: <project>_<prefix>-<number>-<slug>
            # e.g., myproject_feat-1320-some-title
            set pattern ../$current_dir\_*-$arg-*
            set matching_worktrees (ls -d $pattern 2>/dev/null)

            if test (count $matching_worktrees) -eq 0
                __flo_log_error "No worktree found for issue #$arg" "Run 'flo list' to see all worktrees"
                return 1
            else if test (count $matching_worktrees) -gt 1
                __flo_log_error "Multiple worktrees found for issue #$arg:"
                for wt in $matching_worktrees
                    echo "    - $wt" >&2
                end
                echo "    Please specify the full branch name instead" >&2
                return 1
            else
                set worktree_path $matching_worktrees[1]
            end
        else if string match -qr '^[^/]+_' -- $arg
            # Worktree directory name provided (contains _ but no /)
            # e.g., graffle_feat-1320-title -> ../graffle_feat-1320-title
            set worktree_path "../$arg"
        else
            # Branch name provided - calculate path from branch name
            set sanitized_branch (string replace -a '/' '-' $arg)
            set worktree_path "../$current_dir"_"$sanitized_branch"
        end

        # Verify worktree exists
        if not test -d $worktree_path
            __flo_log_error "Worktree not found: $worktree_path" "Run 'flo list' to see all worktrees"
            return 1
        end

        # Get branch name for the worktree
        set -l worktree_realpath (realpath $worktree_path)
        set -l worktree_list (git worktree list --porcelain 2>/dev/null)
        set -l found_worktree false

        for line in $worktree_list
            if string match -q "worktree *" -- $line
                set -l wt_path (string replace "worktree " "" -- $line)
                if test "$wt_path" = "$worktree_realpath"
                    set found_worktree true
                else
                    set found_worktree false
                end
            else if test "$found_worktree" = true; and string match -q "branch *" -- $line
                set branch_name (string replace "branch refs/heads/" "" -- $line)
                break
            end
        end
    end

    # Gather state for preview (dry-run gets detailed state, confirmation just needs PR number)
    set -l pr_number ""
    set -l pr_state ""
    set -l pr_checks_passing ""
    set -l pr_failing_checks
    set -l worktree_clean ""
    set -l branch_synced ""

    # Get PR number for preview (both dry-run and confirmation prompt)
    if not set -q _flag_yes; or set -q _flag_dry
        if test "$ignore_pr" = false -a -n "$branch_name"
            set pr_number (__flo_get_pr_number "$branch_name" 2>/dev/null)
        end
    end

    # Gather detailed state for preview (both dry-run and confirmation prompt)
    if not set -q _flag_yes; or set -q _flag_dry
        if test -n "$pr_number"
            set pr_state (gh pr view "$branch_name" --json state --jq .state 2>/dev/null)
            if test "$pr_state" = OPEN
                # Get individual check statuses
                # Note: CheckRun uses "conclusion", StatusContext uses "state"
                set -l check_results (gh pr view "$branch_name" --json statusCheckRollup --jq '.statusCheckRollup[] | "\(.conclusion // .state)\t\(.name // .context)"' 2>/dev/null)
                set pr_checks_passing true
                for check in $check_results
                    set -l check_state (echo "$check" | cut -f1)
                    set -l check_name (echo "$check" | cut -f2)
                    switch "$check_state"
                        case SUCCESS SKIPPED NEUTRAL
                            # Acceptable
                        case '*'
                            set pr_checks_passing false
                            set -a pr_failing_checks "$check_state:$check_name"
                    end
                end
            end
        end

        if test "$ignore_worktree" = false
            if __flo_validate_clean_worktree "$worktree_path"
                set worktree_clean true
            else
                set worktree_clean false
            end

            if __flo_validate_branch_synced "$worktree_path"
                set branch_synced true
            else
                set branch_synced false
            end
        end
    end

    # Extract issue number from branch name (e.g., feat/91-description -> 91)
    set -l issue_number ""
    if test -n "$branch_name"
        set issue_number (echo "$branch_name" | string replace -r '.*?(\d+).*' '$1')
    end

    # Show preview (for --dry or confirmation prompt)
    if set -q _flag_dry; or not set -q _flag_yes
        echo ""
        echo "  $__flo_c_dim Worktree:$__flo_c_reset $__flo_c_cyan$worktree_path$__flo_c_reset"
        if test -n "$branch_name"
            echo "  $__flo_c_dim Branch:$__flo_c_reset   $__flo_c_cyan$branch_name$__flo_c_reset"
        end
        # Get repo URL once for PR/Issue links
        set -l repo_url ""
        if test -n "$pr_number" -o -n "$issue_number"
            set repo_url (gh repo view --json url --jq .url 2>/dev/null)
        end
        if test -n "$pr_number"
            if test -n "$repo_url"
                echo "  $__flo_c_dim PR:$__flo_c_reset       $__flo_c_cyan$repo_url/pull/$pr_number$__flo_c_reset"
            else
                echo "  $__flo_c_dim PR:$__flo_c_reset       $__flo_c_cyan#$pr_number$__flo_c_reset"
            end
        end
        if test -n "$issue_number"
            if test -n "$repo_url"
                echo "  $__flo_c_dim Issue:$__flo_c_reset    $__flo_c_cyan$repo_url/issues/$issue_number$__flo_c_reset"
            else
                echo "  $__flo_c_dim Issue:$__flo_c_reset    $__flo_c_cyan#$issue_number$__flo_c_reset"
            end
        end

        # Show actual state (both dry-run and interactive confirmation)
        echo ""
        echo "  $__flo_c_dim""State:$__flo_c_reset"

        # PR state
        if test "$ignore_pr" = false
            if test -n "$pr_number"
                if test "$pr_state" = MERGED
                    echo "    $__flo_c_green✓$__flo_c_reset PR #$pr_number: $__flo_c_dim""already merged$__flo_c_reset"
                else if test "$pr_state" = CLOSED
                    echo "    $__flo_c_yellow•$__flo_c_reset PR #$pr_number: $__flo_c_dim""already closed$__flo_c_reset"
                else
                    if test "$pr_checks_passing" = true
                        echo "    $__flo_c_green✓$__flo_c_reset PR #$pr_number: $__flo_c_green""checks passing$__flo_c_reset"
                    else
                        echo "    $__flo_c_red✗$__flo_c_reset PR #$pr_number: $__flo_c_red""checks not passing$__flo_c_reset"
                        # Show failing checks
                        for failing in $pr_failing_checks
                            set -l state (echo "$failing" | cut -d: -f1)
                            set -l name (echo "$failing" | cut -d: -f2-)
                            set -l state_color $__flo_c_red
                            if test "$state" = PENDING
                                set state_color $__flo_c_yellow
                            end
                            echo "      $state_color$state$__flo_c_reset $__flo_c_dim$name$__flo_c_reset"
                        end
                    end
                end
            else
                echo "    $__flo_c_dim•$__flo_c_reset PR: $__flo_c_dim""none$__flo_c_reset"
            end
        end

        # Worktree state
        if test "$ignore_worktree" = false
            if test "$worktree_clean" = true
                echo "    $__flo_c_green✓$__flo_c_reset Worktree: $__flo_c_green""clean$__flo_c_reset"
            else
                echo "    $__flo_c_red✗$__flo_c_reset Worktree: $__flo_c_red""has uncommitted changes$__flo_c_reset"
            end

            if test "$branch_synced" = true
                echo "    $__flo_c_green✓$__flo_c_reset Branch: $__flo_c_green""synced$__flo_c_reset"
            else
                echo "    $__flo_c_red✗$__flo_c_reset Branch: $__flo_c_red""has unpushed commits$__flo_c_reset"
            end
        end

        echo ""
        echo "  This will:"

        # Show PR operations (using actual state gathered above)
        if test "$ignore_pr" = false
            if test -n "$pr_number"
                # PR exists - show specific action based on state
                if test "$pr_state" = MERGED
                    echo "    $__flo_c_dim•$__flo_c_reset Skip PR merge (already merged)"
                else if test "$pr_state" = CLOSED
                    echo "    $__flo_c_dim•$__flo_c_reset Skip PR close (already closed)"
                else if test "$resolve_mode" = success
                    echo "    $__flo_c_blue•$__flo_c_reset Merge PR #$pr_number"
                else
                    echo "    $__flo_c_blue•$__flo_c_reset Close PR #$pr_number without merging"
                end
            else
                echo "    $__flo_c_dim•$__flo_c_reset Skip PR operations (no PR exists)"
            end
        end

        # Show worktree operations
        if test "$ignore_worktree" = false
            if set -q _flag_force
                echo "    $__flo_c_yellow•$__flo_c_reset Remove the worktree (force)"
            else
                echo "    $__flo_c_blue•$__flo_c_reset Remove the worktree"
            end

            if set -q _flag_force
                echo "    $__flo_c_yellow•$__flo_c_reset Force-delete the local branch"
            else
                echo "    $__flo_c_blue•$__flo_c_reset Delete the local branch"
            end
        end

        # Show main sync (happens when PR exists, regardless of whether it gets merged now or was already merged)
        if test "$resolve_mode" = success -a "$ignore_pr" = false
            if test -n "$pr_number"
                # PR exists - main sync will happen (merge is idempotent)
                echo "    $__flo_c_blue•$__flo_c_reset Sync main branch"
            else
                echo "    $__flo_c_dim•$__flo_c_reset Skip main sync (no PR)"
            end
        end

        echo "    $__flo_c_blue•$__flo_c_reset Return to main directory"
        echo ""

        # Dry run - show validation result and exit
        if set -q _flag_dry
            # Check if validations would fail
            set -l would_fail false
            if test "$resolve_mode" = success -a "$ignore_pr" = false; and not set -q _flag_force
                if test -n "$pr_number" -a "$pr_state" = OPEN -a "$pr_checks_passing" = false
                    set would_fail true
                end
            end
            if test "$ignore_worktree" = false; and not set -q _flag_force
                if test "$worktree_clean" = false -o "$branch_synced" = false
                    set would_fail true
                end
            end

            if test "$would_fail" = true
                __flo_log_error "Would fail validation" "Use --force to bypass"
            else
                __flo_log_success Ready
            end
            return 0
        end

        read -l -P "Continue? [y/N]: " confirm

        if test "$confirm" != y -a "$confirm" != Y
            echo Cancelled
            return 0
        end
    end

    # Get main repository directory
    set -l main_worktree (__flo_get_main_worktree)

    # Fallback to parent directory if detection failed
    if test $status -ne 0
        set main_worktree (dirname $worktree_path)
    end

    # VALIDATIONS (success mode only, unless --force)
    if test "$resolve_mode" = success -a "$ignore_pr" = false
        if not set -q _flag_force
            # Check if PR exists (gracefully handles gh not being available)
            set -l pr_number (__flo_get_pr_number "$branch_name")

            if test $status -eq 0
                # PR exists - check if already merged (skip validation for merged PRs)
                set -l pr_state (gh pr view "$branch_name" --json state --jq .state 2>/dev/null)

                if test "$pr_state" != MERGED
                    # PR not yet merged - validate checks
                    # Note: gh availability already confirmed by successful __flo_get_pr_number
                    __flo_log_info "Validating PR checks..."

                    if not __flo_check_pr_status "$branch_name"
                        __flo_log_error "PR checks not passing" "Use --force to bypass, or wait for checks to complete"
                        return 1
                    end

                    __flo_log_success "PR checks passing"
                end
            end

            # Validate worktree is clean
            __flo_log_info "Validating worktree is clean..."

            if not __flo_validate_clean_worktree "$worktree_path"
                __flo_log_error "Worktree has uncommitted changes" "Commit or stash changes, or use --force to bypass"
                return 1
            end

            __flo_log_success "Worktree clean"

            # Validate branch is synced
            __flo_log_info "Validating branch is synced..."

            if not __flo_validate_branch_synced "$worktree_path"
                __flo_log_error "Branch has unpushed commits" "Push commits, or use --force to bypass"
                return 1
            end

            __flo_log_success "Branch synced"
        end
    end

    # PR OPERATIONS (unless --ignore pr)
    # Note: __flo_merge_pr and __flo_close_pr gracefully handle missing gh/PR
    set -l pr_merged false

    if test "$ignore_pr" = false -a -n "$branch_name"
        if test "$resolve_mode" = success
            # Merge PR
            # Only delete remote branch if we're also removing local worktree/branch
            set -l delete_branch_flag false
            if test "$ignore_worktree" = false
                set delete_branch_flag true
            end
            __flo_merge_pr "$branch_name" "$delete_branch_flag"

            if test $status -eq 0
                set pr_merged true
            else
                # Merge failed - exit early
                return 1
            end
        else
            # Close PR without merging
            __flo_close_pr "$branch_name"

            if test $status -ne 0
                # Close failed - exit early
                return 1
            end
        end
    end

    # WORKTREE AND BRANCH CLEANUP (unless --ignore worktree)
    if test "$ignore_worktree" = false
        # Remove worktree
        if set -q _flag_force
            git worktree remove --force $worktree_path
        else
            git worktree remove $worktree_path
        end

        if test $status -eq 0
            __flo_log_success "Removed worktree: $worktree_path"

            # Change to main worktree before branch deletion
            # (shell may still be in deleted worktree directory)
            cd "$main_worktree"

            # Delete the local branch
            set -l force_delete false
            if set -q _flag_force
                set force_delete true
            end
            __flo_delete_branch "$branch_name" "$force_delete"
        else
            __flo_log_error "Failed to remove worktree" "Use --force to remove worktree with uncommitted changes"
            return 1
        end
    end

    # SYNC MAIN BRANCH (if PR was merged)
    if test "$pr_merged" = true
        __flo_sync_main "$main_worktree"
        # Continue even if sync fails (non-critical)
    end

    # NAVIGATE TO MAIN REPO
    cd "$main_worktree"

    return 0
end
