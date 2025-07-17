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

    # Use gum to select worktree with help shown
    set -l selected (echo $worktrees | tr ' ' '\n' | gum choose --header "Select worktree:" --show-help)

    if test -z "$selected"
        return 1
    end

    echo $selected
end
