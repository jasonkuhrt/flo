function flo_end
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

    # No arguments provided - try to remove current worktree
    if test -z "$arg"
        set -l current_path (pwd)
        # Normalize path (resolve symlinks like /tmp -> /private/tmp on macOS)
        set current_path (realpath $current_path)

        # Check if current directory looks like a worktree (contains _)
        if not string match -qr _ -- (basename $current_path)
            echo "✗ Not in a flo worktree"
            echo "Tip: Run 'flo rm <branch>' to remove a specific worktree"
            return 1
        end

        # Verify it's actually a worktree using git
        set -l worktree_list (git worktree list --porcelain 2>/dev/null)
        set -l is_worktree false
        set -l branch_name ""
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
            echo "✗ Not in a flo worktree"
            echo "Tip: Run 'flo rm <branch>' to remove a specific worktree"
            return 1
        end

        # Show confirmation prompt
        echo "Remove current worktree?"
        echo "  Path: $current_path"
        if test -n "$branch_name"
            echo "  Branch: $branch_name"
        end
        read -l -P "Remove? [y/N]: " confirm

        if test "$confirm" != y -a "$confirm" != Y
            echo Cancelled
            return 0
        end

        # Get parent directory (main repo)
        set -l parent_dir (dirname $current_path)

        # Remove worktree
        if test -n "$force_flag"
            git worktree remove --force $current_path
        else
            git worktree remove $current_path
        end

        if test $status -eq 0
            # Change to parent directory
            cd $parent_dir
            echo "✓ Removed worktree: $current_path"
        else
            echo "✗ Failed to remove worktree"
            echo "Tip: Use --force to remove worktree with uncommitted changes"
            return 1
        end

        return 0
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

# Backwards compatibility alias
function flo_rm --description "Alias for flo_end (backwards compatibility)"
    flo_end $argv
end
