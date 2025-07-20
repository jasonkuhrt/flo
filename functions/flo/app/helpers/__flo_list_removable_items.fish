function __flo_list_removable_items --description "List all worktrees with associated issues/PRs for removal"
    set -l items

    # Get all worktrees except main/master
    for wt_path in (git worktree list --porcelain | grep "^worktree" | cut -d' ' -f2)
        set -l wt_name (basename $wt_path)

        # Skip main/master worktrees
        if test "$wt_name" = "$FLO_MAIN_BRANCH" -o "$wt_name" = "$FLO_FALLBACK_BRANCH"
            continue
        end

        set -l display_name ""
        set -l item_info ""

        # Check if it's an issue worktree
        if string match -q "$FLO_ISSUE_PREFIX*" $wt_name
            set -l issue_number (__flo_parse_issue_number $wt_name)
            if test -n "$issue_number"
                set display_name "Issue #$issue_number worktree"
                set item_info "issue:$issue_number"

                # Check if issue exists and get title
                if __flo_check_gh_auth
                    set -l issue_title (gh issue view $issue_number --json title -q .title $FLO_STDERR_NULL)
                    if test -n "$issue_title"
                        set display_name "$display_name: $issue_title"
                    end

                    # Check for associated PR
                    set -l pr_number (__flo_check_pr_exists $issue_number issue)
                    if test -n "$pr_number"
                        set display_name "$display_name (PR #$pr_number)"
                    end
                end
            else
                set display_name "Worktree: $wt_name"
                set item_info "worktree:$wt_name"
            end
        else if string match -q "$FLO_NO_ISSUE_PREFIX*" $wt_name
            set display_name "No-issue worktree: $wt_name"
            set item_info "worktree:$wt_name"
        else
            # Other worktree pattern
            set display_name "Worktree: $wt_name"
            set item_info "worktree:$wt_name"
        end

        # Add to items list with format: "display_name|item_info"
        set items $items "$display_name|$item_info"
    end

    # Output items (one per line)
    for item in $items
        echo $item
    end
end
