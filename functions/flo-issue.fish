function flo-issue --description "Display GitHub issue context for current worktree"
    # Handle --help flag
    if contains -- --help $argv; or contains -- -h $argv
        set -l doc_file ""
        if test -f ./docs/flo-issue.md
            set doc_file ./docs/flo-issue.md
        else if test -f ~/.config/fish/flo-docs/flo-issue.md
            set doc_file ~/.config/fish/flo-docs/flo-issue.md
        else if set -q fisher_path; and test -f $fisher_path/jasonkuhrt/flo/docs/flo-issue.md
            set doc_file $fisher_path/jasonkuhrt/flo/docs/flo-issue.md
        end

        if test -n "$doc_file"
            cat $doc_file
        else
            echo "Error: Documentation not found"
            return 1
        end
        return 0
    end

    # Display Claude context file if it exists in current directory
    if test -f .claude/CLAUDE.local.md
        cat .claude/CLAUDE.local.md
    else
        echo "No issue context found in current worktree"
        echo "Tip: Only worktrees created with 'flo <issue-number>' have issue context"
    end
end
