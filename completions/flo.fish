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

# No arguments = show commands
complete -c flo -f -n "not __fish_seen_subcommand_from create c rm remove r cd claude list ls l status s projects p help h" -a "create" -d "Create a new worktree"
complete -c flo -f -n "not __fish_seen_subcommand_from create c rm remove r cd claude list ls l status s projects p help h" -a "c" -d "Create a new worktree (alias)"
complete -c flo -f -n "not __fish_seen_subcommand_from create c rm remove r cd claude list ls l status s projects p help h" -a "rm" -d "Remove a worktree"
complete -c flo -f -n "not __fish_seen_subcommand_from create c rm remove r cd claude list ls l status s projects p help h" -a "remove" -d "Remove a worktree (alias)"
complete -c flo -f -n "not __fish_seen_subcommand_from create c rm remove r cd claude list ls l status s projects p help h" -a "r" -d "Remove a worktree (alias)"
complete -c flo -f -n "not __fish_seen_subcommand_from create c rm remove r cd claude list ls l status s projects p help h" -a "cd" -d "Change to worktree directory"
complete -c flo -f -n "not __fish_seen_subcommand_from create c rm remove r cd claude list ls l status s projects p help h" -a "claude" -d "Run claude in worktree"
complete -c flo -f -n "not __fish_seen_subcommand_from create c rm remove r cd claude list ls l status s projects p help h" -a "list" -d "List all worktrees"
complete -c flo -f -n "not __fish_seen_subcommand_from create c rm remove r cd claude list ls l status s projects p help h" -a "ls" -d "List all worktrees (alias)"
complete -c flo -f -n "not __fish_seen_subcommand_from create c rm remove r cd claude list ls l status s projects p help h" -a "l" -d "List all worktrees (alias)"
complete -c flo -f -n "not __fish_seen_subcommand_from create c rm remove r cd claude list ls l status s projects p help h" -a "status" -d "Show worktree status"
complete -c flo -f -n "not __fish_seen_subcommand_from create c rm remove r cd claude list ls l status s projects p help h" -a "s" -d "Show worktree status (alias)"
complete -c flo -f -n "not __fish_seen_subcommand_from create c rm remove r cd claude list ls l status s projects p help h" -a "projects" -d "List all projects"
complete -c flo -f -n "not __fish_seen_subcommand_from create c rm remove r cd claude list ls l status s projects p help h" -a "p" -d "List all projects (alias)"
complete -c flo -f -n "not __fish_seen_subcommand_from create c rm remove r cd claude list ls l status s projects p help h" -a "help" -d "Show help"
complete -c flo -f -n "not __fish_seen_subcommand_from create c rm remove r cd claude list ls l status s projects p help h" -a "h" -d "Show help (alias)"

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

# List command - complete with --all flag
complete -c flo -f -n "__fish_seen_subcommand_from list ls l; and not contains -- --all (commandline -opc)" -a "--all" -d "Show all worktrees across all projects"