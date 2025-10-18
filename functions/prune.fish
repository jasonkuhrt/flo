function flo_prune
    # Clean up Git metadata for manually deleted worktrees
    echo "• Pruning deleted worktrees..."
    git worktree prune -v
    echo "✓ Done"
end
