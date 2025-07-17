# Claude AI integration

function claude --description "Add current branch context to Claude"
    argparse --name="flo claude" h/help a/all c/clean -- $argv; or return

    if set -q _flag_help
        echo "Usage: flo claude [options]"
        echo ""
        echo "Generate Claude context files for current or all worktrees."
        echo ""
        echo "Options:"
        echo "  -h, --help    Show this help message"
        echo "  -a, --all     Generate context for all worktrees"
        echo "  -c, --clean   Clean up old context files"
        echo ""
        echo "Examples:"
        echo "  flo claude                # Generate context for current worktree"
        echo "  flo claude --all          # Generate context for all worktrees"
        echo "  flo claude --clean        # Clean old context files"
        return 0
    end

    set -l claude_dir ~/Library/CloudStorage/Dropbox/Documents-Dropbox/Contextual/claude
    set -l target_dir "$claude_dir/prompts"

    # Ensure directory exists
    if not test -d $target_dir
        echo "Claude prompts directory not found: $target_dir"
        echo "Please create the directory or configure FLO_CLAUDE_DIR environment variable"
        return 1
    end

    # Get current branch and repo info
    set -l current_branch (git branch --show-current 2>/dev/null)
    if test -z "$current_branch"
        echo "Not in a git repository"
        return 1
    end

    set -l repo_name (basename (__flo_get_repo_root))
    set -l prompt_file "$target_dir/$repo_name-$current_branch.md"

    # Get issue/PR info if available
    set -l issue_number (__flo_parse_issue_number $current_branch)
    set -l pr_info ""

    if __flo_check_gh_auth
        if test -n "$issue_number"
            # Use gh template for formatting
            set -l pr_info (gh issue view $issue_number --template '## Issue #{{.number}}{{"\n"}}{{.title}}{{"\n\n"}}{{.body}}{{"\n\n"}}URL: {{.url}}' 2>/dev/null)
        else
            # Use gh template for PR formatting
            set -l pr_info (gh pr view --template '## PR #{{.number}}{{"\n"}}{{.title}}{{"\n\n"}}{{.body}}{{"\n\n"}}URL: {{.url}}' 2>/dev/null)
        end
    end

    # Create prompt file
    echo "# Context for $repo_name - $current_branch" >$prompt_file
    echo "" >>$prompt_file
    echo "Repository: $repo_name" >>$prompt_file
    echo "Branch: $current_branch" >>$prompt_file
    echo "Date: "(date) >>$prompt_file
    echo "" >>$prompt_file

    if test -n "$pr_info"
        echo $pr_info >>$prompt_file
        echo "" >>$prompt_file
    end

    # Add recent commits
    echo "## Recent Commits" >>$prompt_file
    git log --oneline -10 >>$prompt_file
    echo "" >>$prompt_file

    # Add file changes
    echo "## Changed Files" >>$prompt_file
    git diff --name-status origin/main...$current_branch >>$prompt_file

    echo "Created Claude prompt at: $prompt_file"

    # Open in editor if available
    if command -v code >/dev/null
        code $prompt_file
    end
end

function claude-clean --description "Remove old Claude context files"
    set -l claude_dir ~/Library/CloudStorage/Dropbox/Documents-Dropbox/Contextual/claude
    set -l target_dir "$claude_dir/prompts"

    if not test -d $target_dir
        echo "Claude prompts directory not found: $target_dir"
        return 1
    end

    set -l repo_name (basename (__flo_get_repo_root) 2>/dev/null)

    if test -z "$repo_name"
        # Clean all old files
        set -l old_files (find $target_dir -name "*.md" -mtime +7)
    else
        # Clean old files for current repo
        set -l old_files (find $target_dir -name "$repo_name-*.md" -mtime +7)
    end

    if test (count $old_files) -eq 0
        echo "No old context files to clean"
        return 0
    end

    echo "Found "(count $old_files)" old context files:"
    for file in $old_files
        echo "  - "(basename $file)
    end

    if gum confirm "Delete these files?"
        rm $old_files
        gum style --foreground 2 "✓ Deleted "(count $old_files)" files"
    else
        echo Cancelled
    end
end
