# Next issue workflow command

function flo-next --description "Start next issue (context-aware)"
    argparse --name="flo next" 'h/help' 'no-claude' -- $argv; or return
    
    if set -q _flag_help
        echo "Usage: flo next [issue-number]"
        echo ""
        echo "Context-aware next issue command:"
        echo "- In worktree: transition workflow (delete → sync → create → claude)"
        echo "- In main project: regular issue workflow (create → claude)"
        echo ""
        echo "Options:"
        echo "  --no-claude   Skip Claude launch"
        echo "  -h, --help    Show this help"
        echo ""
        echo "Examples:"
        echo "  flo next              Select from issue list"
        echo "  flo next 123          Work on issue #123"
        echo "  flo next 123 --no-claude  Work on issue #123 without Claude"
        return 0
    end
    
    # Validate we're in a git project
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Must be run from within a git project" >&2
        return 1
    end
    
    # Get issue number
    set -l issue_number $argv[1]
    if test -z "$issue_number"
        echo "Select an issue to work on:"
        set issue_number (__flo_select_issue); or return 1
    end
    
    # Get Claude session (if not disabled)
    set -l session_id ""
    if not set -q _flag_no_claude
        set session_id (__flo_prompt_claude_session)
        if test $status -ne 0
            echo "Invalid session ID provided, continuing without Claude session resume"
            set session_id ""
        end
    end
    
    # Detect context and execute appropriate workflow
    set -l current_worktree (__flo_get_current_worktree_name)
    
    if test -n "$current_worktree"
        # In worktree: full transition workflow
        echo "Transitioning from $current_worktree to issue #$issue_number..."
        
        # Delete current worktree
        __flo_remove_current_worktree; or begin
            echo "Failed to remove current worktree" >&2
            return 1
        end
        echo "✓ Deleted worktree: $current_worktree"
        
        # Sync main branch
        __flo_sync_main_branch; or begin
            echo "Failed to sync main branch" >&2
            return 1
        end
        echo "✓ Synced main branch"
        
        # Create new issue worktree
        flo-issue $issue_number; or begin
            echo "Failed to create new worktree" >&2
            return 1
        end
        echo "✓ Created worktree: issue/$issue_number"
        
    else
        # In main project: regular issue workflow
        echo "No current worktree to transition from, starting issue #$issue_number..."
        
        # Create new issue worktree
        flo-issue $issue_number; or begin
            echo "Failed to create new worktree" >&2
            return 1
        end
        echo "✓ Created worktree: issue/$issue_number"
    end
    
    # Launch Claude if session provided or not disabled
    if test -n "$session_id"
        echo "Resuming Claude session..."
        claude --resume $session_id
    else if not set -q _flag_no_claude
        echo "Starting new Claude session..."
        claude
    end
end