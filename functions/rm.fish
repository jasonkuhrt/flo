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

    # Show what will be done
    echo "Issue #$issue_number cleanup:"
    echo ""

    # Check if issue exists and is open
    if __flo_check_gh_auth
        set -l issue_state (gh issue view $issue_number --json state -q .state 2>/dev/null)
        if test -n "$issue_state"
            if set -q _flag_close_issue
                if test "$issue_state" = OPEN
                    echo "  • Close issue #$issue_number: YES"
                else
                    echo "  • Issue #$issue_number: already closed"
                end
            else
                echo "  • Close issue #$issue_number: NO (use --close-issue to close)"
            end
        else
            echo "  • Issue #$issue_number: not found"
        end

        # Check if PR exists and is open
        set -l pr_state (gh pr list --state all --search "head:issue/$issue_number" --json state -q '.[0].state' 2>/dev/null)
        if test -n "$pr_state"
            if set -q _flag_close_pr
                if test "$pr_state" = OPEN
                    echo "  • Close PR for issue #$issue_number: YES"
                else
                    echo "  • PR for issue #$issue_number: already closed/merged"
                end
            else
                echo "  • Close PR for issue #$issue_number: NO (use --close-pr to close)"
            end
        else
            echo "  • PR for issue #$issue_number: not found"
        end
    end

    # Check worktree
    if not set -q _flag_no_delete_worktree
        if __flo_worktree_exists $target_worktree
            echo "  • Delete worktree '$target_worktree': YES"
        else
            # Check for other worktree patterns
            set -l found_worktree ""
            for wt in (git worktree list --porcelain | grep "^worktree" | cut -d' ' -f2)
                if string match -q "*$issue_number*" (basename $wt)
                    set found_worktree (basename $wt)
                    break
                end
            end

            if test -n "$found_worktree"
                echo "  • Delete worktree '$found_worktree': YES"
                set target_worktree $found_worktree
            else
                echo "  • Worktree for issue #$issue_number: not found"
            end
        end
    else
        echo "  • Delete worktree: NO (--no-delete-worktree specified)"
    end

    echo ""

    # Skip confirmation if --force flag is set
    if not set -q _flag_force
        if not gum confirm "Proceed with cleanup?"
            echo Cancelled
            return 0
        end
    end

    # Execute the cleanup

    # If we're in the worktree to be deleted, move out first
    if test $in_worktree -eq 1 -a ! set -q _flag_no_delete_worktree
        echo "Moving to main repository before deletion..."
        cd (__flo_get_repo_root)
    end

    # Delete worktree if requested
    if not set -q _flag_no_delete_worktree
        if __flo_worktree_exists $target_worktree
            echo "Deleting worktree '$target_worktree'..."
            flo worktree delete $target_worktree
            if test $status -eq 0
                echo "✓ Deleted worktree"
            else
                echo "✗ Failed to delete worktree" >&2
            end
        end
    end

    # Close PR if requested
    if set -q _flag_close_pr -a __flo_check_gh_auth
        set -l pr_number (gh pr list --state open --search "head:issue/$issue_number" --json number -q '.[0].number' 2>/dev/null)
        if test -n "$pr_number"
            echo "Closing PR #$pr_number..."
            gh pr close $pr_number
            if test $status -eq 0
                echo "✓ Closed PR"
            else
                echo "✗ Failed to close PR" >&2
            end
        end
    end

    # Close issue if requested
    if set -q _flag_close_issue -a __flo_check_gh_auth
        set -l issue_state (gh issue view $issue_number --json state -q .state 2>/dev/null)
        if test "$issue_state" = OPEN
            echo "Closing issue #$issue_number..."
            gh issue close $issue_number
            if test $status -eq 0
                echo "✓ Closed issue"
            else
                echo "✗ Failed to close issue" >&2
            end
        end
    end

    echo ""
    echo "Cleanup complete for issue #$issue_number"
end
