function __flo_get_issue_from_context --description "Extract issue number from current context (worktree or branch)"
    # Check for explicit issue number argument
    if test (count $argv) -gt 0
        set -l issue_ref $argv[1]
        if string match -qr '^[0-9]+$' $issue_ref
            echo $issue_ref
            return 0
        end
    end

    # Try to extract from current worktree name
    set -l current_worktree (__flo_get_current_worktree_name)
    if test -n "$current_worktree"
        set -l issue_number (__flo_parse_issue_number $current_worktree)
        if test -n "$issue_number"
            echo $issue_number
            return 0
        end
    end

    # Try to extract from current branch name
    set -l current_branch (git branch --show-current 2>/dev/null)
    if test -n "$current_branch"
        set -l issue_number (__flo_parse_issue_number $current_branch)
        if test -n "$issue_number"
            echo $issue_number
            return 0
        end
    end

    # No issue number found
    return 1
end
