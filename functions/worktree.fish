# Git worktree management functions

function worktree --description "Manage git worktrees"
    # Check for help flag
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: flo worktree <subcommand>"
        echo ""
        echo "Subcommands:"
        echo "  create <name>    Create a new worktree"
        echo "  delete <name>    Delete a worktree"
        echo "  list             List all worktrees"
        echo "  switch <name>    Switch to a worktree"
        echo ""
        echo "Examples:"
        echo "  flo worktree create feature-x"
        echo "  flo worktree delete feature-x"
        echo "  flo worktree list"
        return 0
    end

    set -l cmd $argv[1]
    set -e argv[1]

    switch $cmd
        case create
            __flo_worktree_create $argv
        case delete remove
            __flo_worktree_delete $argv
        case list
            __flo_worktree_list
        case switch
            __flo_worktree_switch $argv
        case '*'
            echo "Usage: flo worktree <create|delete|list|switch> [args...]"
            return 1
    end
end

function __flo_worktree_create --description "Create a new git worktree"
    set -l branch_name $argv[1]

    if test -z "$branch_name"
        echo "Usage: flo worktree create <branch-name>"
        return 1
    end

    set -l location (__flo_get_worktree_location)
    set -l worktree_path "$location/$branch_name"

    if __flo_worktree_exists $branch_name
        echo "Worktree '$branch_name' already exists"
        return 1
    end

    # Create worktree
    git worktree add -b $branch_name $worktree_path

    if test $status -eq 0
        echo "Created worktree at: $worktree_path"
        __flo_open_editor $worktree_path
    end
end

function __flo_worktree_delete --description "Delete a git worktree"
    set -l branch_name $argv[1]

    # If no branch name provided, use fzf to select
    if test -z "$branch_name"
        set branch_name (__flo_select_worktree)
        if test $status -ne 0
            echo "No worktree selected" >&2
            return 1
        end
    end

    if not __flo_worktree_exists $branch_name
        echo "Worktree '$branch_name' does not exist"
        return 1
    end

    # Remove worktree
    git worktree remove $branch_name --force

    # Delete branch if it exists
    git branch -D $branch_name 2>/dev/null

    echo "Deleted worktree and branch: $branch_name"
end

function __flo_worktree_list --description "List all git worktrees"
    # Check for help flag
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: flo worktree list"
        echo ""
        echo "List all git worktrees for the current repository."
        echo ""
        echo "Shows each worktree's branch name and directory path."
        return 0
    end

    # Simple worktree list with branch and path
    git worktree list | while read -l line
        set -l parts (string split " " $line)
        set -l path $parts[1]
        set -l branch (string match -r '\[(.+)\]' $line | string replace -r '^\[|\]$' '')
        if test -n "$branch"
            printf "%-40s %s\n" $branch $path
        end
    end | column -t
end

function __flo_worktree_switch --description "Switch to a git worktree"
    set -l branch_name $argv[1]

    # If no branch name provided, use fzf to select
    if test -z "$branch_name"
        set branch_name (__flo_select_worktree exclude-current)
        if test $status -ne 0
            echo "No worktree selected" >&2
            return 1
        end
    end

    set -l location (__flo_get_worktree_location)
    set -l worktree_path "$location/$branch_name"

    if not test -d $worktree_path
        echo "Worktree '$branch_name' does not exist at: $worktree_path"
        return 1
    end

    cd $worktree_path
    echo "Switched to worktree: $branch_name"
end
