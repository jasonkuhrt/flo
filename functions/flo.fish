# Loader script for flo functions
# This file sources all the flo modules in the correct order

set -l flo_dir (dirname (status -f))

# Load modules in dependency order
source $flo_dir/errors.fish
source $flo_dir/helpers.fish
source $flo_dir/worktree.fish
source $flo_dir/issue.fish
source $flo_dir/pr.fish
source $flo_dir/browse.fish
source $flo_dir/claude.fish
source $flo_dir/next.fish
source $flo_dir/rm.fish
source $flo_dir/completions.fish

# Main flo command dispatcher
function flo --description "Git workflow automation tool"
    set -l cmd $argv[1]
    set -e argv[1]

    switch $cmd
        case issue
            issue $argv
        case issue-create
            issue-create $argv
        case pr
            pr $argv
        case worktree
            worktree $argv
        case list
            browse $argv
        case status
            flo_status $argv
        case projects
            projects $argv
        case claude
            claude $argv
        case claude-clean
            claude-clean $argv
        case next
            next $argv
        case rm
            rm $argv
        case reload
            __flo_reload $argv
        case help ''
            echo "flo - Git workflow automation tool"
            echo ""
            echo "Commands:"
            echo "  issue <number|title>    Start work on a GitHub issue"
            echo "  issue-create <title>    Create a new issue and start working on it"
            echo "  next [number]           Transition to next issue (context-aware)"
            echo "  rm [number]             Remove issue, PR, and/or worktree"
            echo "  pr [create|push|checks|merge]  Manage pull requests"
            echo "  worktree <create|delete|list|switch>  Manage git worktrees"
            echo "  list <issues|prs|worktrees>  List various items"
            echo "  status                  Show current worktree and PR status"
            echo "  projects                List GitHub projects"
            echo "  claude                  Add current branch context to Claude"
            echo "  claude-clean            Remove old Claude context files"
            echo "  help                    Show this help message"
        case '*'
            echo "Unknown command: $cmd"
            echo "Run 'flo help' for usage information"
            return 1
    end
end
