# Claude AI integration

function flo_claude --description "Add current branch context to Claude"
    argparse --name="flo claude" h/help a/all c/clean -- $argv
    or return

    if set -q _flag_help
        __flo_show_help \
            --usage "flo claude [options]" \
            --description "Generate Claude context files for current or all worktrees." \
            --options "-h, --help    Show this help message
-a, --all     Generate context for all worktrees
-c, --clean   Clean up old context files

Environment Variables:
  FLO_CLAUDE_DIR    Directory to save context files (default: current directory)" \
            --examples "flo claude                # Generate context for current worktree
flo claude --all          # Generate context for all worktrees
flo claude --clean        # Clean old context files

export FLO_CLAUDE_DIR=~/Documents/claude-contexts
flo claude                # Save to custom directory"
        return 0
    end

    # Use environment variable or default to current directory
    set -l claude_dir (set -q FLO_CLAUDE_DIR; and echo $FLO_CLAUDE_DIR; or echo ".")
    set -l target_dir "$claude_dir"

    # Ensure directory exists
    if not test -d $target_dir
        echo "Claude context directory not found: $target_dir"
        echo "Please create the directory or set FLO_CLAUDE_DIR environment variable"
        return 1
    end

    # Get current branch and repo info
    set -l current_branch (git branch --show-current 2>/dev/null)
    if test -z "$current_branch"
        echo "Not in a git repository"
        return 1
    end

    set -l repo_name (__flo_get_repo_name); or return
    set -l prompt_file "$target_dir/$repo_name-$current_branch.md"

    # Get issue/PR info if available
    set -l issue_number (__flo_get_issue_from_context)
    set -l pr_info ""

    if __flo_check_gh_auth
        if test -n "$issue_number"
            # Use gh template for formatting
            set -l pr_info (gh issue view $issue_number --template '## Issue #{{.number}}{{"\n"}}{{.title}}{{"\n\n"}}{{.body}}{{"\n\n"}}URL: {{.url}}' 2>/dev/null)
        else
            # Check if there's a PR for current branch
            set -l pr_number (__flo_check_pr_exists $current_branch branch)
            if test -n "$pr_number"
                # Use gh template for PR formatting
                set -l pr_info (gh pr view $pr_number --template '## PR #{{.number}}{{"\n"}}{{.title}}{{"\n\n"}}{{.body}}{{"\n\n"}}URL: {{.url}}' 2>/dev/null)
            end
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

    # Optionally show full diff if requested
    if contains -- --show-diff $argv
        echo "" >>$prompt_file
        echo "## Full Diff" >>$prompt_file
        echo '```diff' >>$prompt_file
        if __flo_has_command delta
            # Use delta for formatted diff output
            git diff origin/main...$current_branch --no-color >>$prompt_file
        else
            git diff origin/main...$current_branch >>$prompt_file
        end
        echo '```' >>$prompt_file
    end

    echo "Created Claude prompt at: $prompt_file"

    # Open in editor if available
    if __flo_has_command code
        code $prompt_file
    end
end
