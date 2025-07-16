# Completions for flo (GitHub Issue Flow Tool)

# Disable file completions by default
complete -c flo -f

# Helper function to get current project name
function __flo_current_project
    if git rev-parse --git-dir >/dev/null 2>&1
        set -l remote_url (git remote get-url origin 2>/dev/null)
        if test -n "$remote_url"
            echo "$remote_url" | sed -E 's|.*/([^/]+)(\.git)?$|\1|' | sed 's/\.git$//'
        else
            basename (git rev-parse --show-toplevel)
        end
    end
end

# Helper function to get worktree names for current project
function __flo_worktree_names
    set -l base_root (test -n "$FLO_BASE_DIR"; and echo "$FLO_BASE_DIR"; or echo "$HOME/worktrees")
    set -l project (__flo_current_project)
    if test -n "$project" -a -d "$base_root/$project"
        for worktree in "$base_root/$project"/*
            if test -d "$worktree"
                basename $worktree
            end
        end
    end
end

# Helper function to get all project names
function __flo_project_names
    set -l base_root (test -n "$FLO_BASE_DIR"; and echo "$FLO_BASE_DIR"; or echo "$HOME/worktrees")
    if test -d "$base_root"
        for project in "$base_root"/*
            if test -d "$project"
                basename $project
            end
        end
    end
end

# Helper function to get project/worktree combinations
function __flo_project_worktree_names
    set -l base_root (test -n "$FLO_BASE_DIR"; and echo "$FLO_BASE_DIR"; or echo "$HOME/worktrees")
    if test -d "$base_root"
        for project in "$base_root"/*
            if test -d "$project"
                set -l project_name (basename $project)
                for worktree in "$project"/*
                    if test -d "$worktree"
                        echo "$project_name/"(basename $worktree)
                    end
                end
            end
        end
    end
end

# Helper function to get branch names
function __flo_branch_names
    git branch -a 2>/dev/null | string replace -r '^\s*\*?\s*' '' | string replace -r '^remotes/origin/' '' | sort -u
end

# Helper to check if we have no subcommand yet
function __flo_no_subcommand
    set -l cmd (commandline -opc)
    if test (count $cmd) -eq 1
        return 0
    end
    # Check if second arg is a number (issue workflow)
    if test (count $cmd) -ge 2; and string match -qr '^[0-9]+$' -- $cmd[2]
        return 1
    end
    # Check if we have a known subcommand
    set -l subcommands create c rm remove r cd claude list ls l status s projects p issues i pr sync zed z help h
    if contains -- $cmd[2] $subcommands
        return 1
    end
    return 0
end

# Helper to check if using issue workflow
function __flo_is_issue_workflow
    set -l cmd (commandline -opc)
    if test (count $cmd) -ge 2; and string match -qr '^[0-9]+$' -- $cmd[2]
        return 0
    end
    return 1
end

# Main command completions (when no subcommand)
complete -c flo -n __flo_no_subcommand -a "create c" -d "Create a new worktree"
complete -c flo -n __flo_no_subcommand -a "rm remove r" -d "Remove a worktree"
complete -c flo -n __flo_no_subcommand -a cd -d "Change to worktree directory"
complete -c flo -n __flo_no_subcommand -a claude -d "Start Claude in worktree with context"
complete -c flo -n __flo_no_subcommand -a "list ls l" -d "List worktrees"
complete -c flo -n __flo_no_subcommand -a "status s" -d "Show detailed status"
complete -c flo -n __flo_no_subcommand -a "projects p" -d "List all projects with worktrees"
complete -c flo -n __flo_no_subcommand -a "issues i" -d "List repository issues"
complete -c flo -n __flo_no_subcommand -a pr -d "Manage pull requests"
complete -c flo -n __flo_no_subcommand -a sync -d "Update caches and clean merged PRs"
complete -c flo -n __flo_no_subcommand -a "zed z" -d "Open worktree in Zed editor"
complete -c flo -n __flo_no_subcommand -a "help h" -d "Show help"

# Issue numbers (dynamic completion with --keep-order)
complete -c flo -n __flo_no_subcommand -k -a "(gh issue list --state open --json number,title --jq '.[] | \"\(.number)\t\(.title)\"' 2>/dev/null)"

# Global flags
complete -c flo -s h -l help -d "Show help" -x

# Command: create
complete -c flo -n "__fish_seen_subcommand_from create c" -xa "(__flo_branch_names)" -d "Branch name"

# Command: remove (multiple worktrees allowed)
complete -c flo -n "__fish_seen_subcommand_from rm remove r" -xa "(__flo_worktree_names)" -d "Worktree"

# Command: cd
complete -c flo -n "__fish_seen_subcommand_from cd" -xa "(__flo_worktree_names)" -d "Worktree in current project"
complete -c flo -n "__fish_seen_subcommand_from cd" -xa "(__flo_project_worktree_names)" -d "Worktree in other project"

# Command: claude (optional argument - can be run without args in a worktree)
complete -c flo -n "__fish_seen_subcommand_from claude" -xa "(__flo_worktree_names)" -d "Worktree"
complete -c flo -n "__fish_seen_subcommand_from claude" -xa "(__flo_project_worktree_names)" -d "Worktree in other project"

# Command: status
complete -c flo -n "__fish_seen_subcommand_from status s" -xa "(__flo_worktree_names)" -d "Worktree"
complete -c flo -n "__fish_seen_subcommand_from status s" -l project -r -xa "all (__flo_project_names)" -d "Filter by project"

# Command: list
complete -c flo -n "__fish_seen_subcommand_from list ls l" -l all -d "Show all worktrees across all projects"

# Command: zed
complete -c flo -n "__fish_seen_subcommand_from zed z" -xa "(__flo_worktree_names)" -d "Worktree in current project"
complete -c flo -n "__fish_seen_subcommand_from zed z" -xa "(__flo_project_worktree_names)" -d "Worktree in other project"

# Issue workflow flags
complete -c flo -n __flo_is_issue_workflow -l zed -d "Open in Zed editor"
complete -c flo -n __flo_is_issue_workflow -l claude -d "Start Claude with context"

# PR subcommands
complete -c flo -n "__fish_seen_subcommand_from pr; and not __fish_seen_subcommand_from create c open o status s list l" -xa "create c" -d "Create a new pull request"
complete -c flo -n "__fish_seen_subcommand_from pr; and not __fish_seen_subcommand_from create c open o status s list l" -xa "open o" -d "Open PR in browser"
complete -c flo -n "__fish_seen_subcommand_from pr; and not __fish_seen_subcommand_from create c open o status s list l" -xa "status s" -d "Show PR status for current branch"
complete -c flo -n "__fish_seen_subcommand_from pr; and not __fish_seen_subcommand_from create c open o status s list l" -xa "list l" -d "List all open PRs"

# Prevent file completion for commands that don't need it
complete -c flo -n "__fish_seen_subcommand_from projects p issues i sync help h" -f
complete -c flo -n "__fish_seen_subcommand_from pr; and __fish_seen_subcommand_from create c open o status s list l" -f

# Add dynamic issue completions that refresh
function __flo_issues_with_status
    set -l worktree_issues
    set -l base_root (test -n "$FLO_BASE_DIR"; and echo "$FLO_BASE_DIR"; or echo "$HOME/worktrees")
    set -l project (__flo_current_project)
    
    if test -n "$project" -a -d "$base_root/$project"
        for worktree in "$base_root/$project"/*
            if test -d "$worktree"
                set -l name (basename $worktree)
                if string match -qr '^issue/([0-9]+)$' -- $name
                    set -a worktree_issues (string replace -r '^issue/([0-9]+)$' '$1' -- $name)
                end
            end
        end
    end
    
    gh issue list --state open --json number,title --jq '.[]' 2>/dev/null | while read -l issue
        set -l num (echo $issue | jq -r '.number')
        set -l title (echo $issue | jq -r '.title' | string sub -l 50)
        if contains -- $num $worktree_issues
            echo "$num\t✓ $title"
        else
            echo "$num\t$title"
        end
    end
end

# Override issue completion with enhanced version
complete -c flo -n __flo_no_subcommand -k -xa "(__flo_issues_with_status)"