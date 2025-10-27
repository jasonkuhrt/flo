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
    set -l keep_branch $argv[3] # "true" if --keep-branch flag was provided

    if test -z "$branch_name"
        return 0
    end

    # Skip if --keep-branch flag is set
    if test "$keep_branch" = true
        __flo_log_info_dim "Kept branch: $branch_name"
        return 0
    end

    # Choose deletion flag based on force mode
    set -l delete_flag -d
    if test "$force_delete" = true
        set delete_flag -D
    end

    # Attempt to delete the branch
    if git branch $delete_flag "$branch_name" 2>/dev/null
        __flo_log_success "Deleted branch: $branch_name"
        return 0
    else
        # Branch deletion failed
        if test "$delete_flag" = -d
            __flo_log_error "Failed to delete branch: $branch_name" "Branch has unmerged changes. Use --force to force delete, or --keep-branch to preserve"
        else
            __flo_log_error "Failed to delete branch: $branch_name"
        end
        return 1
    end
end

function flo_end
    # Parse flags
    argparse f/force y/yes k/keep-branch 'project=' -- $argv; or return

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

    set current_dir (basename $project_path)
    set -l arg $argv[1]

    # Set force flag if provided
    set -l force_flag ""
    if set -q _flag_force
        set force_flag --force
    end

    # No arguments provided - try to remove current worktree
    if test -z "$arg"
        set -l current_path (pwd)
        # Normalize path (resolve symlinks like /tmp -> /private/tmp on macOS)
        set current_path (realpath $current_path)

        # Check if current directory looks like a worktree (contains _)
        if not string match -qr _ -- (basename $current_path)
            __flo_log_error "Not in a flo worktree" "Run 'flo end <branch>' to remove a specific worktree"
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
            __flo_log_error "Not in a flo worktree" "Run 'flo end <branch>' to remove a specific worktree"
            return 1
        end

        # Show confirmation prompt (unless --yes flag provided)
        if not set -q _flag_yes
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
        end

        # Get main repository directory
        set -l main_worktree (__flo_get_main_worktree)

        # Fallback to parent directory if detection failed
        if test $status -ne 0
            set main_worktree (dirname $current_path)
        end

        # Remove worktree
        if test -n "$force_flag"
            git worktree remove --force $current_path
        else
            git worktree remove $current_path
        end

        if test $status -eq 0
            # Change to main repository directory
            cd $main_worktree
            __flo_log_success "Removed worktree: $current_path"

            # Delete the branch unless --keep-branch is set
            set -l force_delete false
            if set -q _flag_force
                set force_delete true
            end
            set -l keep_branch false
            if set -q _flag_keep_branch
                set keep_branch true
            end
            __flo_delete_branch "$branch_name" "$force_delete" "$keep_branch"
        else
            __flo_log_error "Failed to remove worktree" "Use --force to remove worktree with uncommitted changes"
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

    # Remove worktree if it exists
    if test -d $worktree_path
        # Get branch name before removing worktree
        set -l worktree_realpath (realpath $worktree_path)
        set -l worktree_list (git worktree list --porcelain 2>/dev/null)
        set -l found_worktree false
        set -l branch_name ""

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

        if test -n "$force_flag"
            git worktree remove --force $worktree_path
        else
            git worktree remove $worktree_path
        end

        if test $status -eq 0
            # Change to main repository directory for consistency
            set -l main_worktree (__flo_get_main_worktree)
            if test $status -eq 0
                cd $main_worktree
            end
            __flo_log_success "Removed worktree: $worktree_path"

            # Delete the branch unless --keep-branch is set
            set -l force_delete false
            if set -q _flag_force
                set force_delete true
            end
            set -l keep_branch false
            if set -q _flag_keep_branch
                set keep_branch true
            end
            __flo_delete_branch "$branch_name" "$force_delete" "$keep_branch"
        else
            __flo_log_error "Failed to remove worktree" "Use --force to remove worktree with uncommitted changes"
            return 1
        end
    else
        __flo_log_error "Worktree not found: $worktree_path" "Run 'flo list' to see all worktrees"
        return 1
    end
end
