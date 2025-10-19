function flo_list
    # Source internals for config helpers
    set -l flo_dir (dirname (status -f))
    source "$flo_dir/../lib/internals.fish"

    # Colors for output
    set -l cyan (set_color brcyan)
    set -l dim (set_color brblack)
    set -l reset (set_color normal)

    # Load global tracking data
    set -l tracking_data (__flo_internal_config_load)

    # Get worktree list in porcelain format for easier parsing
    set -l worktrees (git worktree list --porcelain)

    # Print table header
    printf "%s%-8s %-30s %s%s\n" "$dim" ISSUE BRANCH PATH "$reset"

    # Parse worktree entries (each entry is 3-4 lines in porcelain format)
    set -l path ""
    set -l branch ""

    for line in $worktrees
        if string match -qr '^worktree ' -- $line
            # Extract path
            set path (string replace 'worktree ' '' -- $line)
        else if string match -qr '^branch ' -- $line
            # Extract branch name
            set branch (string replace 'branch refs/heads/' '' -- $line)
        else if test "$line" = ""
            # Empty line marks end of entry - print the row
            if test -n "$path" -a -n "$branch"
                # Try to get issue number from tracking file
                set -l issue_num (echo $tracking_data | jq -r --arg path "$path" '.[$path].issue // "-"')

                # Fallback: Extract from branch name if not in tracking file
                if test "$issue_num" = -
                    set issue_num (string replace -rf '^[^/]+/(\d+)-.*' '$1' -- $branch)
                    # If extraction didn't work (no match), use "-"
                    if test "$issue_num" = "$branch"
                        set issue_num -
                    end
                end

                # Get relative path from current dir
                set -l rel_path (string replace (pwd)/ '' -- $path)
                if test "$rel_path" = "$path"
                    # Not a subdirectory, show basename
                    set rel_path (basename $path)
                end

                printf "%-8s %-30s %s\n" "$issue_num" "$branch" "$rel_path"
            end

            # Reset for next entry
            set path ""
            set branch ""
        end
    end

    # Handle last entry (no trailing empty line)
    if test -n "$path" -a -n "$branch"
        # Try to get issue number from tracking file
        set -l issue_num (echo $tracking_data | jq -r --arg path "$path" '.[$path].issue // "-"')

        # Fallback: Extract from branch name if not in tracking file
        if test "$issue_num" = -
            set issue_num (string replace -rf '^[^/]+/(\d+)-.*' '$1' -- $branch)
            if test "$issue_num" = "$branch"
                set issue_num -
            end
        end

        set -l rel_path (string replace (pwd)/ '' -- $path)
        if test "$rel_path" = "$path"
            set rel_path (basename $path)
        end
        printf "%-8s %-30s %s\n" "$issue_num" "$branch" "$rel_path"
    end
end
