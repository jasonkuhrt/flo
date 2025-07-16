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
source $flo_dir/completions.fish

# Main flo command dispatcher
function flo --description "Git workflow automation tool"
    set -l cmd $argv[1]
    set -e argv[1]
    
    switch $cmd
        case issue
            flo-issue $argv
        case issue-create
            flo-issue-create $argv
        case pr
            flo-pr $argv
        case worktree
            flo-worktree $argv
        case list
            flo-list $argv
        case status
            flo-status $argv
        case projects
            flo-projects $argv
        case claude
            flo-claude $argv
        case claude-clean
            flo-claude-clean $argv
        case help ''
            echo "flo - Git workflow automation tool"
            echo ""
            echo "Commands:"
            echo "  issue <number|title>    Start work on a GitHub issue"
            echo "  issue-create <title>    Create a new issue and start working on it"
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