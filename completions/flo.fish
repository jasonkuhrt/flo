# Completions for flo (Git Worktree Manager)

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
    git branch -a 2>/dev/null | string replace -r '^\s*\*?\s*' '' | string replace -r '^remotes/origin/' ''
end

# Main commands
set -l commands create c rm remove r cd claude list ls l status s projects p issues i pr sync zed z help h
set -l commands_regex (string join '|' $commands)

# No arguments = show commands
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "create" -d "Create a new worktree"
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "c" -d "Create a new worktree (alias)"
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "rm" -d "Remove a worktree"
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "remove" -d "Remove a worktree (alias)"
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "r" -d "Remove a worktree (alias)"
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "cd" -d "Change to worktree directory"
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "claude" -d "Start Claude in worktree with context"
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "list" -d "List worktrees"
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "ls" -d "List worktrees (alias)"
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "l" -d "List worktrees (alias)"
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "status" -d "Show detailed status"
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "s" -d "Show detailed status (alias)"
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "projects" -d "List all projects"
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "p" -d "List all projects (alias)"
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "issues" -d "List repository issues"
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "i" -d "List repository issues (alias)"
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "pr" -d "Manage pull requests"
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "sync" -d "Update caches and clean merged PRs"
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "zed" -d "Open worktree in Zed"
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "z" -d "Open worktree in Zed (alias)"
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "help" -d "Show help"
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "h" -d "Show help (alias)"

# Global --help flag (available for all commands)
complete -c flo -f -n "__fish_seen_subcommand_from $commands" -l help -d "Show help for this command"

# Issue numbers (when no subcommand)
complete -c flo -f -n "not __fish_seen_subcommand_from $commands" -a "(gh issue list --json number,title --jq '.[] | \"\(.number)\t\(.title)\"' 2>/dev/null)" -d "Issue"

# Create command - second argument can be branch name
complete -c flo -f -n "__fish_seen_subcommand_from create c; and test (count (commandline -opc)) -eq 3" -a "(__flo_branch_names)" -d "Source branch"

# Remove command - complete with existing worktree names in current project
complete -c flo -f -n "__fish_seen_subcommand_from rm remove r" -a "(__flo_worktree_names)" -d "Worktree"

# CD command - complete with both current project worktrees and project/worktree combinations
complete -c flo -f -n "__fish_seen_subcommand_from cd" -a "(__flo_worktree_names)" -d "Worktree in current project"
complete -c flo -f -n "__fish_seen_subcommand_from cd" -a "(__flo_project_worktree_names)" -d "Worktree in other project"

# Claude command - complete with existing worktree names in current project
complete -c flo -f -n "__fish_seen_subcommand_from claude" -a "(__flo_worktree_names)" -d "Worktree"

# Status command - complete with existing worktree names in current project
complete -c flo -f -n "__fish_seen_subcommand_from status s" -a "(__flo_worktree_names)" -d "Worktree"

# Command-specific flags
# List command
complete -c flo -f -n "__fish_seen_subcommand_from list ls l; and not contains -- --all (commandline -opc)" -l all -d "Show all worktrees across all projects"

# Status command  
complete -c flo -f -n "__fish_seen_subcommand_from status s; and not contains -- --project (commandline -opc)" -l project -d "Filter by project"
complete -c flo -f -n "__fish_seen_subcommand_from status s; and contains -- --project (commandline -opc); and not contains -- all (commandline -opc)" -a "all" -d "Show all projects"
complete -c flo -f -n "__fish_seen_subcommand_from status s; and contains -- --project (commandline -opc)" -a "(__flo_project_names)" -d "Project"

# Issue workflow flags (for numeric commands)
complete -c flo -f -n "string match -qr '^[0-9]+' (commandline -opc)[-1]; and not contains -- --zed (commandline -opc)" -l zed -d "Open in Zed editor"
complete -c flo -f -n "string match -qr '^[0-9]+' (commandline -opc)[-1]; and not contains -- --claude (commandline -opc)" -l claude -d "Start Claude with context"

# PR subcommands
complete -c flo -f -n "__fish_seen_subcommand_from pr; and not __fish_seen_subcommand_from create c open o status s list l" -a "create" -d "Create a new pull request"
complete -c flo -f -n "__fish_seen_subcommand_from pr; and not __fish_seen_subcommand_from create c open o status s list l" -a "c" -d "Create a new pull request (alias)"
complete -c flo -f -n "__fish_seen_subcommand_from pr; and not __fish_seen_subcommand_from create c open o status s list l" -a "open" -d "Open PR in browser"
complete -c flo -f -n "__fish_seen_subcommand_from pr; and not __fish_seen_subcommand_from create c open o status s list l" -a "o" -d "Open PR in browser (alias)"
complete -c flo -f -n "__fish_seen_subcommand_from pr; and not __fish_seen_subcommand_from create c open o status s list l" -a "status" -d "Show PR status"
complete -c flo -f -n "__fish_seen_subcommand_from pr; and not __fish_seen_subcommand_from create c open o status s list l" -a "s" -d "Show PR status (alias)"
complete -c flo -f -n "__fish_seen_subcommand_from pr; and not __fish_seen_subcommand_from create c open o status s list l" -a "list" -d "List all open PRs"
complete -c flo -f -n "__fish_seen_subcommand_from pr; and not __fish_seen_subcommand_from create c open o status s list l" -a "l" -d "List all open PRs (alias)"

# Zed command - complete with worktree names
complete -c flo -f -n "__fish_seen_subcommand_from zed z" -a "(__flo_worktree_names)" -d "Worktree in current project"
complete -c flo -f -n "__fish_seen_subcommand_from zed z" -a "(__flo_project_worktree_names)" -d "Worktree in other project"