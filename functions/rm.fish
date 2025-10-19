function flo_rm
    set current_dir (basename (pwd))

    # Parse arguments
    set -l force_flag ""
    set -l arg ""

    for arg_item in $argv
        if test "$arg_item" = --force -o "$arg_item" = -f
            set force_flag --force
        else
            set arg $arg_item
        end
    end

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
            echo "✗ No worktree found for issue #$arg"
            echo "Tip: Run 'flo list' to see all worktrees"
            return 1
        else if test (count $matching_worktrees) -gt 1
            echo "✗ Multiple worktrees found for issue #$arg:"
            for wt in $matching_worktrees
                echo "  - $wt"
            end
            echo "Please specify the full branch name instead"
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

    # Remove worktree if it exists
    if test -d $worktree_path
        if test -n "$force_flag"
            git worktree remove --force $worktree_path
        else
            git worktree remove $worktree_path
        end

        if test $status -eq 0
            echo "✓ Removed worktree: $worktree_path"
        else
            echo "✗ Failed to remove worktree"
            echo "Tip: Use --force to remove worktree with uncommitted changes"
            return 1
        end
    else
        echo "✗ Worktree not found: $worktree_path"
        echo "Tip: Run 'flo list' to see all worktrees"
        return 1
    end
end
