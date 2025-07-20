# Remove command - clean up issues, PRs, and worktrees

function flo_rm --description "Remove issue, PR, and/or worktree"
    argparse --name="flo rm" \
        h/help \
        'issue=?' \
        close-issue \
        close-pr \
        no-delete-worktree \
        f/force \
        -- $argv; or return

    if set -q _flag_help
        __flo_show_help \
            --usage "flo rm [issue-number] [options]" \
            --description "Remove issue, pull request, and/or worktree.
By default, deletes the worktree but leaves issue and PR open.
If no issue number provided, shows interactive selection of removable items." \
            --args "issue-number    Issue number to remove (optional: shows selection if omitted)" \
            --options "--close-issue         Close the GitHub issue (default: no)
--close-pr            Close the pull request (default: no)
--no-delete-worktree  Don't delete the worktree (default: delete)
-f, --force           Skip confirmation prompt
-h, --help            Show this help" \
            --examples "flo rm                    Show interactive selection of items to remove
flo rm 123                Delete worktree for issue #123
flo rm --close-issue      Delete worktree and close issue
flo rm --close-pr --close-issue  Delete worktree, close PR and issue"
        return 0
    end

    # Get issue number from argument or current context, or show selection
    set -l issue_number ""
    set -l selected_worktree ""

    if test (count $argv) -gt 0
        # Issue number provided as argument
        set issue_number $argv[1]
        if not string match -qr '^[0-9]+$' $issue_number
            __flo_error "Invalid issue number: $issue_number"
            return 1
        end
    else
        # Try to get from current context first
        set issue_number (__flo_get_issue_from_context)

        if test -z "$issue_number"
            # Show interactive selection of available items
            set -l removable_items (__flo_list_removable_items)

            if test -z "$removable_items"
                echo "No worktrees available for removal"
                return 0
            end

            # Prepare choices for gum (display names only)
            set -l choices
            for item in $removable_items
                set -l display_name (string split "|" $item)[1]
                set choices $choices "$display_name"
            end

            # Show selection
            set -l selected_display (gum choose \
                --header "Select item to remove:" \
                $choices)

            if test -z "$selected_display"
                echo "No item selected"
                return 0
            end

            # Find the corresponding item info
            for item in $removable_items
                set -l parts (string split "|" $item)
                if test "$parts[1]" = "$selected_display"
                    set -l item_info $parts[2]
                    set -l item_parts (string split ":" $item_info)
                    set -l item_type $item_parts[1]
                    set -l item_value $item_parts[2]

                    if test "$item_type" = issue
                        set issue_number $item_value
                    else if test "$item_type" = worktree
                        set selected_worktree $item_value
                    end
                    break
                end
            end
        end
    end

    # Validate issue number (if we have one)
    if test -n "$issue_number"; and not __flo_validate_issue_number $issue_number
        __flo_error "Invalid issue number: $issue_number"
        return 1
    end

    # Handle non-issue worktree removal
    if test -z "$issue_number"; and test -n "$selected_worktree"
        echo "Removing non-issue worktree: $selected_worktree"

        # Check if we're in the worktree to be deleted
        set -l current_worktree (__flo_get_current_worktree_name)
        if test "$current_worktree" = "$selected_worktree"
            echo "Moving to main repository before deletion..."
            cd (__flo_get_repo_root)
        end

        # Delete the worktree
        if __flo_worktree_exists $selected_worktree
            echo "Deleting worktree '$selected_worktree'..."
            __flo_delete_worktree $selected_worktree
            if test $status -eq 0
                __flo_success "✓ Deleted worktree '$selected_worktree'"
            else
                __flo_error "✗ Failed to delete worktree"
                return 1
            end
        else
            __flo_error "Worktree '$selected_worktree' not found"
            return 1
        end

        return 0
    end

    # If we still don't have an issue number, something went wrong
    if test -z "$issue_number"
        __flo_error "No issue number or worktree selected"
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

        set -l pr_number (__flo_check_pr_exists $issue_number issue)
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
    if test $worktree_found -eq 1; and not set -q _flag_no_delete_worktree
        set selected_actions $selected_actions "Delete worktree '$target_worktree'"
    end

    if test (count $available_actions) -eq 0
        echo "Nothing to clean up for issue #$issue_number"
        return 0
    end

    # Skip interactive selection if --force flag is set
    if not set -q _flag_force
        # Use gum choose with multi-select for actions
        set -l chosen_actions (__flo_gum_select_multi \
            --header "Select cleanup actions for issue #$issue_number:" \
            --selected $selected_actions \
            -- $available_actions)

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
    if test $in_worktree -eq 1; and test $do_delete_worktree -eq 1
        echo "Moving to main repository before deletion..."
        cd (__flo_get_repo_root)
    end

    # Delete worktree if requested
    if test $do_delete_worktree -eq 1
        if __flo_worktree_exists $target_worktree
            echo "Deleting worktree '$target_worktree'..."
            __flo_delete_worktree $target_worktree
            if test $status -eq 0
                __flo_success "✓ Deleted worktree"
            else
                __flo_error "✗ Failed to delete worktree"
            end
        end
    end

    # Close PR if requested
    if test $do_close_pr -eq 1; and __flo_check_gh_auth
        set -l pr_number (__flo_check_pr_exists $issue_number issue)
        if test -n "$pr_number"
            echo "Closing PR #$pr_number..."
            gh pr close $pr_number
            if test $status -eq 0
                __flo_success "✓ Closed PR"
            else
                __flo_error "✗ Failed to close PR"
            end
        end
    end

    # Close issue if requested
    if test $do_close_issue -eq 1; and __flo_check_gh_auth
        set -l issue_state (gh issue view $issue_number --json state -q .state 2>/dev/null)
        if test "$issue_state" = OPEN
            echo "Closing issue #$issue_number..."
            gh issue close $issue_number
            if test $status -eq 0
                __flo_success "✓ Closed issue"
            else
                __flo_error "✗ Failed to close issue"
            end
        end
    end

    echo ""
    echo "Cleanup complete for issue #$issue_number"
end
