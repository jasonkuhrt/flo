# Source shared libraries
set -l flo_dir (dirname (status --current-filename))
source "$flo_dir/__flo_lib_log.fish"

function flo_prune
    # Parse flags
    argparse 'project=' -- $argv; or return

    # Resolve project path if --project provided
    if set -q _flag_project
        set -l project_path (__flo_resolve_project_path "$_flag_project")
        if test $status -ne 0
            # Error already printed by resolver
            return 1
        end
        cd "$project_path" || return 1
    end

    # Clean up Git metadata for manually deleted worktrees
    __flo_log_info "Pruning deleted worktrees..."
    git worktree prune -v
    __flo_log_success Done
end
