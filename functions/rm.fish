# Remove command - clean up issues, PRs, and worktrees

function rm --description "Remove issue, PR, and/or worktree"
    argparse --name="flo rm" \
        h/help \
        'issue=?' \
        close-issue \
        close-pr \
        no-delete-worktree \
        f/force \
        -- $argv; or return

    if set -q _flag_help
        echo "Usage: flo rm [issue-number] [options]"
        echo ""
        echo "Remove issue, pull request, and/or worktree."
        echo "By default, deletes the worktree but leaves issue and PR open."
        echo ""
        echo "Arguments:"
        echo "  issue-number    Issue number to remove (default: current worktree's issue)"
        echo ""
        echo "Options:"
        echo "  --close-issue         Close the GitHub issue (default: no)"
        echo "  --close-pr            Close the pull request (default: no)"
        echo "  --no-delete-worktree  Don't delete the worktree (default: delete)"
        echo "  -f, --force           Skip confirmation prompt"
        echo "  -h, --help            Show this help"
        echo ""
        echo "Examples:"
        echo "  flo rm                    Delete current worktree, keep issue/PR open"
        echo "  flo rm 123                Delete worktree for issue #123"
        echo "  flo rm --close-issue      Delete worktree and close issue"
        echo "  flo rm --close-pr --close-issue  Delete worktree, close PR and issue"
        return 0
    end

    # Get issue number from argument or current context
    set -l issue_number $argv[1]

    # If no issue number provided, try to get from current worktree
    if test -z "$issue_number"
        set -l current_worktree (__flo_get_current_worktree_name)

        if test -z "$current_worktree"
            echo "Error: No issue number provided and not in an issue worktree" >&2
            echo "Usage: flo rm <issue-number>" >&2
            return 1
        end

        # Extract issue number from worktree name (e.g., "issue/123" or "123-fix-bug")
        set issue_number (__flo_parse_issue_number $current_worktree)

        if test -z "$issue_number"
            echo "Error: Could not determine issue number from worktree '$current_worktree'" >&2
            return 1
        end
    end

    # Validate issue number
    if not string match -qr '^[0-9]+$' -- $issue_number
        echo "Error: Invalid issue number: $issue_number" >&2
        return 1
    end

    # Get current context
    set -l in_worktree 0
    set -l current_worktree (__flo_get_current_worktree_name)
    set -l target_worktree "issue/$issue_number"

    # Check if we're in the target worktree
    if test -n "$current_worktree"
        if string match -q "*$issue_number*" $current_worktree
            set in_worktree 1
        end
    end

    # Build list of available actions
    set -l available_actions
    set -l selected_actions

    # Check what's available
    if __flo_check_gh_auth
        set -l issue_state (gh issue view $issue_number --json state -q .state 2>/dev/null)
        if test "$issue_state" = OPEN
            set available_actions $available_actions "Close issue #$issue_number"
            if set -q _flag_close_issue
                set selected_actions $selected_actions "Close issue #$issue_number"
            end
        end

        set -l pr_number (gh pr list --state open --search "head:issue/$issue_number" --json number -q '.[0].number' 2>/dev/null)
        if test -n "$pr_number"
            set available_actions $available_actions "Close PR #$pr_number"
            if set -q _flag_close_pr
                set selected_actions $selected_actions "Close PR #$pr_number"
            end
        end
    end

    # Check worktree
    set -l worktree_found 0
    if __flo_worktree_exists $target_worktree
        set available_actions $available_actions "Delete worktree '$target_worktree'"
        set worktree_found 1
    else
        # Check for other worktree patterns
        for wt in (git worktree list --porcelain | grep "^worktree" | cut -d' ' -f2)
            if string match -q "*$issue_number*" (basename $wt)
                set target_worktree (basename $wt)
                set available_actions $available_actions "Delete worktree '$target_worktree'"
                set worktree_found 1
                break
            end
        end
    end

    # Add to selected if not explicitly disabled
    if test $worktree_found -eq 1 -a ! set -q _flag_no_delete_worktree
        set selected_actions $selected_actions "Delete worktree '$target_worktree'"
    end

    if test (count $available_actions) -eq 0
        echo "Nothing to clean up for issue #$issue_number"
        return 0
    end

    # Skip interactive selection if --force flag is set
    if not set -q _flag_force
        # Use gum choose with multi-select for actions
        set -l chosen_actions (printf '%s\n' $available_actions | gum choose \
            --no-limit \
            --show-help \
            --header "Select cleanup actions for issue #$issue_number:" \
            --selected (printf '%s\n' $selected_actions))

        if test -z "$chosen_actions"
            echo "No actions selected"
            return 0
        end

        # Parse chosen actions
        set -l do_close_issue 0
        set -l do_close_pr 0
        set -l do_delete_worktree 0

        for action in $chosen_actions
            if string match -q "Close issue*" $action
                set do_close_issue 1
            else if string match -q "Close PR*" $action
                set do_close_pr 1
            else if string match -q "Delete worktree*" $action
                set do_delete_worktree 1
            end
        end
    else
        # Use flags directly when --force is set
        set -l do_close_issue 0
        set -l do_close_pr 0
        set -l do_delete_worktree 1

        if set -q _flag_close_issue
            set do_close_issue 1
        end
        if set -q _flag_close_pr
            set do_close_pr 1
        end
        if set -q _flag_no_delete_worktree
            set do_delete_worktree 0
        end
    end

    # Execute the cleanup

    # If we're in the worktree to be deleted, move out first
    if test $in_worktree -eq 1 -a $do_delete_worktree -eq 1
        echo "Moving to main repository before deletion..."
        cd (__flo_get_repo_root)
    end

    # Delete worktree if requested
    if test $do_delete_worktree -eq 1
        if __flo_worktree_exists $target_worktree
            echo "Deleting worktree '$target_worktree'..."
            flo worktree delete $target_worktree
            if test $status -eq 0
                gum style --foreground 2 "✓ Deleted worktree"
            else
                gum log --level error "✗ Failed to delete worktree"
            end
        end
    end

    # Close PR if requested
    if test $do_close_pr -eq 1 -a __flo_check_gh_auth
        set -l pr_number (gh pr list --state open --search "head:issue/$issue_number" --json number -q '.[0].number' 2>/dev/null)
        if test -n "$pr_number"
            echo "Closing PR #$pr_number..."
            gh pr close $pr_number
            if test $status -eq 0
                gum style --foreground 2 "✓ Closed PR"
            else
                gum log --level error "✗ Failed to close PR"
            end
        end
    end

    # Close issue if requested
    if test $do_close_issue -eq 1 -a __flo_check_gh_auth
        set -l issue_state (gh issue view $issue_number --json state -q .state 2>/dev/null)
        if test "$issue_state" = OPEN
            echo "Closing issue #$issue_number..."
            gh issue close $issue_number
            if test $status -eq 0
                gum style --foreground 2 "✓ Closed issue"
            else
                gum log --level error "✗ Failed to close issue"
            end
        end
    end

    echo ""
    echo "Cleanup complete for issue #$issue_number"
end
