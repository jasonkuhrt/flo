# Next issue workflow command

function flo_next --description "Start next issue (context-aware)"
    argparse --name="flo next" h/help no-claude -- $argv; or return

    if set -q _flag_help
        __flo_show_help \
            --usage "flo next [issue-number]" \
            --description "Context-aware next workflow command:
- In worktree: transition workflow (delete → sync → create → claude)
- In main project: regular workflow (create → claude)
- When no issues available: option to continue without issue" \
            --args "issue-number    Optional issue number to work on" \
            --options "--no-claude   Skip Claude launch
-h, --help    Show this help" \
            --examples "flo next              Select from issue list or continue without issue
flo next 123          Work on issue #123
flo next 123 --no-claude  Work on issue #123 without Claude

No-issue workflow:
When no GitHub issues are available, you can choose to continue without
an issue. This creates a worktree with pattern: no-issue/YYYYMMDD-HHMMSS"
        return 0
    end

    # Validate we're in a git project
    if not git rev-parse --git-dir >/dev/null 2>&1
        __flo_error "Must be run from within a git project"
        return 1
    end

    # Get issue number or no-issue indicator
    set -l issue_number $argv[1]
    if test -z "$issue_number"
        set issue_number (__flo_select_issue); or return 1
    end

    # Handle no-issue case - generate random worktree name or use custom name
    set -l worktree_name ""
    set -l is_no_issue 0
    if string match -q "$FLO_NO_ISSUE*" "$issue_number"
        set is_no_issue 1

        # Check if custom name was provided
        if string match -q "$FLO_NO_ISSUE:*" "$issue_number"
            # Extract custom name after the colon
            set -l custom_name (string split -m 1 ":" "$issue_number")[2]
            set worktree_name "$FLO_NO_ISSUE_PREFIX$custom_name"
            echo "Creating worktree without issue: $worktree_name"
        else
            # Use default timestamp-based name
            set worktree_name "$FLO_NO_ISSUE_PREFIX"(date $FLO_TIMESTAMP_FORMAT)
            echo "Creating worktree without issue: $worktree_name"
        end
    else
        set worktree_name "$FLO_ISSUE_PREFIX$issue_number"
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
        if test $is_no_issue -eq 1
            echo "Transitioning from $current_worktree to new worktree without issue..."
        else
            echo "Transitioning from $current_worktree to issue #$issue_number..."
        end

        # Delete current worktree
        __flo_remove_current_worktree; or begin
            __flo_error "Failed to remove current worktree"
            return 1
        end
        echo "✓ Deleted worktree: $current_worktree"

        # Sync main branch
        __flo_gum_spin --title "Syncing main branch..." -- __flo_sync_main_branch; or begin
            __flo_error "Failed to sync main branch"
            return 1
        end
        __flo_success "✓ Synced main branch"

        # Create new worktree
        if test $is_no_issue -eq 1
            __flo_create_worktree $worktree_name; or begin
                __flo_error "Failed to create new worktree"
                return 1
            end
        else
            flo issue $issue_number; or begin
                __flo_error "Failed to create new worktree"
                return 1
            end
        end
        echo "✓ Created worktree: $worktree_name"

    else
        # In main project: regular workflow
        if test $is_no_issue -eq 1
            echo "No current worktree to transition from, creating new worktree without issue..."
            __flo_create_worktree $worktree_name; or begin
                __flo_error "Failed to create new worktree"
                return 1
            end
        else
            echo "No current worktree to transition from, starting issue #$issue_number..."
            flo issue $issue_number; or begin
                __flo_error "Failed to create new worktree"
                return 1
            end
        end
        echo "✓ Created worktree: $worktree_name"
    end

    # Launch Claude if session provided or not disabled
    if test -n "$session_id"
        echo "Resuming Claude session..."
        flo claude --resume $session_id
    else if not set -q _flag_no_claude
        echo "Starting new Claude session..."
        flo claude
    end
end
