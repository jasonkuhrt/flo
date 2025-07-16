# Claude AI integration

function flo-claude --description "Add current branch context to Claude"
    set -l claude_dir ~/Library/CloudStorage/Dropbox/Documents-Dropbox/Contextual/claude
    set -l target_dir "$claude_dir/prompts"
    
    # Ensure directory exists
    if not test -d $target_dir
        echo "Claude prompts directory not found: $target_dir"
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
            set -l issue_data (gh issue view $issue_number --json title,body,url 2>/dev/null)
            if test $status -eq 0
                set -l pr_info (echo $issue_data | jq -r '"## Issue #\(.number)\n\(.title)\n\n\(.body)\n\nURL: \(.url)"')
            end
        else
            set -l pr_data (gh pr view --json number,title,body,url 2>/dev/null)
            if test $status -eq 0
                set -l pr_info (echo $pr_data | jq -r '"## PR #\(.number)\n\(.title)\n\n\(.body)\n\nURL: \(.url)"')
            end
        end
    end
    
    # Create prompt file
    echo "# Context for $repo_name - $current_branch" > $prompt_file
    echo "" >> $prompt_file
    echo "Repository: $repo_name" >> $prompt_file
    echo "Branch: $current_branch" >> $prompt_file
    echo "Date: "(date) >> $prompt_file
    echo "" >> $prompt_file
    
    if test -n "$pr_info"
        echo $pr_info >> $prompt_file
        echo "" >> $prompt_file
    end
    
    # Add recent commits
    echo "## Recent Commits" >> $prompt_file
    git log --oneline -10 >> $prompt_file
    echo "" >> $prompt_file
    
    # Add file changes
    echo "## Changed Files" >> $prompt_file
    git diff --name-status origin/main...$current_branch >> $prompt_file
    
    echo "Created Claude prompt at: $prompt_file"
    
    # Open in editor if available
    if command -v code >/dev/null
        code $prompt_file
    end
end

function flo-claude-clean --description "Remove old Claude context files"
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
    
    read -P "Delete these files? (y/N) " confirm
    if test "$confirm" = "y" -o "$confirm" = "Y"
        rm $old_files
        echo "Deleted "(count $old_files)" files"
    else
        echo "Cancelled"
    end
end