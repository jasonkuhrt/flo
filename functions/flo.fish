# Loader script for flo functions
# This file sources all the flo modules in the correct order

set -l flo_dir (dirname (status -f))

# Load modules in dependency order
source $flo_dir/helpers.fish
source $flo_dir/issue.fish
source $flo_dir/pr.fish
source $flo_dir/claude.fish
source $flo_dir/next.fish
source $flo_dir/flo_rm.fish
source $flo_dir/completions.fish

# Main flo command dispatcher
function flo --description "Git workflow automation tool"
    set -l cmd $argv[1]
    set -e argv[1]

    switch $cmd
        case issue
            issue $argv
        case pr
            pr $argv
        case next
            next $argv
        case rm
            flo_rm $argv
        case claude
            claude $argv
        case reload
            __flo_reload $argv
        case help ''
            echo "flo - Git workflow automation tool"
            echo ""
            echo "Commands:"
            echo "  issue <number|title>    Start work on a GitHub issue"
            echo "  next [number]           Transition to next issue (context-aware)"
            echo "  rm [number]             Remove issue, PR, and/or worktree"
            echo "  pr                      Create pull request for current branch"
            echo "  claude                  Add current branch context to Claude"
            echo "  help                    Show this help message"
        case '*'
            echo "Unknown command: $cmd"
            echo "Run 'flo help' for usage information"
            return 1
    end
end
