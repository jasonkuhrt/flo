#!/usr/bin/env fish
# Main entry point for flo - GitHub Issue Flow Tool

function flo --description "GitHub issue flow tool for managing worktrees"
    # Use argparse for better argument handling
    argparse --name=flo h/help -- $argv
    or return

    # Handle help flag
    if set -q _flag_help
        __flo_help
        return 0
    end

    # Get command
    set -l cmd $argv[1]
    set -e argv[1]

    # Check for empty command
    if not set -q cmd
        __flo_help
        return 0
    end

    # Show help and exit
    if contains -- $cmd help h
        __flo_help
        return 0
    end

    # Check if cmd is a number (issue workflow)
    if string match -qr '^\d+$' -- $cmd
        __flo_issue $cmd $argv
        return
    end

    # Determine if we're in a git repository
    set -l in_git_repo (git rev-parse --git-dir &>/dev/null; and echo true; or echo false)
    set -l project_name ""
    set -l base_root (set -q FLO_BASE_DIR; and echo $FLO_BASE_DIR; or echo "$HOME/worktrees")
    set -l base_dir ""

    # Commands that require git repository
    set -l git_required_cmds create c

    # Check if command requires git
    if contains -- $cmd $git_required_cmds
        if test $in_git_repo = false
            set_color red
            echo "Error: Command '$cmd' requires a git repository"
            set_color normal
            return 1
        end
    end

    # Get project context if in git repo
    if test $in_git_repo = true
        set -l project_name (__flo_get_project_name)
        if not set -q project_name[1]
            set_color red
            echo "Error: Could not determine project name"
            set_color normal
            return 1
        end
        set -l base_dir "$base_root/$project_name"
    end

    # Configuration
    set -l branch_prefix (set -q FLO_BRANCH_PREFIX; and echo $FLO_BRANCH_PREFIX; or echo "claude/")
    set -l issue_prefix (set -q FLO_ISSUE_PREFIX; and echo $FLO_ISSUE_PREFIX; or echo "issue/")

    switch $cmd
        case create c
            # Requires git (checked above)
            __flo_create $base_dir $branch_prefix $issue_prefix $argv

        case rm remove r
            # Doesn't require git - works with paths
            __flo_remove $base_root $in_git_repo $project_name $argv

        case cd
            # Doesn't require git - just navigation
            __flo_cd $base_root $in_git_repo $project_name $argv

        case claude
            # May require git if creating new worktree
            __flo_claude $base_root $in_git_repo $project_name $branch_prefix $issue_prefix $argv

        case list ls l
            # Doesn't require git
            __flo_list $base_root $in_git_repo $project_name $argv

        case status s
            # Doesn't require git
            __flo_status $base_root $in_git_repo $project_name $argv

        case projects p
            # Doesn't require git
            __flo_projects $base_root

        case issues i
            # Requires git to list repo issues
            if test $in_git_repo = false
                set_color red
                echo "Error: Command 'issues' requires a git repository"
                set_color normal
                return 1
            end
            __flo_issues

        case pr
            # Requires git for PR operations
            if test $in_git_repo = false
                set_color red
                echo "Error: Command 'pr' requires a git repository"
                set_color normal
                return 1
            end
            __flo_pr $argv

        case sync
            # Doesn't require git at top level
            __flo_sync $base_root

        case zed z
            # Doesn't require git
            __flo_zed $base_root $in_git_repo $project_name $argv

        case '*'
            # Don't show error for --help since it's handled above
            if not contains -- $cmd --help
                set_color red
                echo "Unknown command: $cmd"
                set_color normal
            end
            __flo_help
            return 1
    end
end
