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
    echo "• Pruning deleted worktrees..."
    git worktree prune -v
    echo "✓ Done"
end
