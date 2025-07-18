function __flo_select_worktree --description "Let user select from available worktrees"
    set -l exclude_current $argv[1] # Optional: pass "exclude-current" to exclude current worktree

    # Get current worktree name if excluding
    set -l current_worktree ""
    if test "$exclude_current" = exclude-current
        set current_worktree (basename (pwd))
    end

    # Get list of worktrees
    set -l worktrees (git worktree list --porcelain | grep "^worktree" | cut -d' ' -f2 | while read -l path
        set -l name (basename $path)
        # Skip main/master and optionally current
        if test "$name" != "main" -a "$name" != "master"
            if test -z "$current_worktree" -o "$name" != "$current_worktree"
                echo $name
            end
        end
    end)

    if test -z "$worktrees"
        echo "No worktrees available" >&2
        return 1
    end

    # Count worktrees to decide between choose and filter
    set -l worktree_count (count $worktrees)

    # Use filter for more than 8 worktrees, choose for smaller lists
    if test $worktree_count -gt 8
        # Use gum filter for fuzzy search
        set -l selected (echo $worktrees | tr ' ' '\n' | gum filter \
            --placeholder "Type to filter $worktree_count worktrees..." \
            --header "Search worktrees:" \
            --height 12)
    else
        # Use gum choose for small lists
        set -l selected (echo $worktrees | tr ' ' '\n' | gum choose --header "Select worktree:" --show-help)
    end

    if test -z "$selected"
        return 1
    end

    echo $selected
end
