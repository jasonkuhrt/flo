function flo --description "GitHub issue flow tool"
    # Parse arguments
    set -l cmd $argv[1]
    set -e argv[1]

    # Check for --help flag only if it's the first argument or no command
    if test -z "$cmd"; or test "$cmd" = --help
        __flo_help
        return 0
    end

    # Show help and exit
    if contains -- $cmd help h
        __flo_help
        return 0
    end

    # Check if cmd is a number (issue workflow)
    if string match -qr '^\d+$' -- $cmd
        __flo_issue $cmd $argv
        return
    end

    # Determine if we're in a git repository
    set -l in_git_repo (git rev-parse --git-dir >/dev/null 2>&1; and echo true; or echo false)
    set -l project_name ""
    set -l base_root (test -n "$FLO_BASE_DIR"; and echo "$FLO_BASE_DIR"; or echo "$HOME/worktrees")
    set -l base_dir ""

    # Commands that require git repository
    set -l git_required_cmds create c

    # Check if command requires git
    if contains -- $cmd $git_required_cmds
        if test $in_git_repo = false
            set_color red
            echo "Error: Command '$cmd' requires a git repository"
            set_color normal
            return 1
        end
    end

    # Get project context if in git repo
    if test $in_git_repo = true
        set project_name (__flo_get_project_name)
        if test -z "$project_name"
            set_color red
            echo "Error: Could not determine project name"
            set_color normal
            return 1
        end
        set base_dir "$base_root/$project_name"
    end

    # Configuration
    set -l branch_prefix (test -n "$FLO_BRANCH_PREFIX"; and echo "$FLO_BRANCH_PREFIX"; or echo "claude/")
    set -l issue_prefix (test -n "$FLO_ISSUE_PREFIX"; and echo "$FLO_ISSUE_PREFIX"; or echo "issue/")

    switch $cmd
        case create c
            # Requires git (checked above)
            __flo_create $base_dir $branch_prefix $issue_prefix $argv

        case rm remove r
            # Doesn't require git - works with paths
            __flo_remove $base_root $in_git_repo $project_name $argv

        case cd
            # Doesn't require git - just navigation
            __flo_cd $base_root $in_git_repo $project_name $argv

        case claude
            # May require git if creating new worktree
            __flo_claude $base_root $in_git_repo $project_name $branch_prefix $issue_prefix $argv

        case next n
            # Context-aware next issue workflow
            flo-next $argv

        case list ls l
            # Doesn't require git
            __flo_list $base_root $in_git_repo $project_name $argv

        case status s
            # Doesn't require git
            __flo_status $base_root $in_git_repo $project_name $argv

        case projects p
            # Doesn't require git
            __flo_projects $base_root

        case issues i
            # Requires git to list repo issues
            if test $in_git_repo = false
                set_color red
                echo "Error: Command 'issues' requires a git repository"
                set_color normal
                return 1
            end
            __flo_issues

        case pr
            # Requires git for PR operations
            if test $in_git_repo = false
                set_color red
                echo "Error: Command 'pr' requires a git repository"
                set_color normal
                return 1
            end
            __flo_pr $argv

        case sync
            # Doesn't require git at top level
            __flo_sync $base_root

        case zed z
            # Doesn't require git
            __flo_zed $base_root $in_git_repo $project_name $argv

        case '*'
            # Don't show error for --help since it's handled above
            if not contains -- $cmd --help
                set_color red
                echo "Unknown command: $cmd"
                set_color normal
            end
            __flo_help
            return 1
    end
end

function __flo_get_project_name
    # Allow override via environment variable
    if test -n "$FLO_PROJECT_NAME"
        echo "$FLO_PROJECT_NAME"
        return 0
    end

    # Try to get from remote origin
    set -l remote_url (git remote get-url origin 2>/dev/null)
    if test -n "$remote_url"
        # Extract repo name from URL (works with both HTTPS and SSH URLs)
        set -l repo_name (string replace -r '.*/([^/]+)(\.git)?$' '$1' $remote_url)
        if test -n "$repo_name"
            echo "$repo_name"
            return 0
        end
    end

    # Fallback to directory name
    basename (git rev-parse --show-toplevel)
end

function __flo_help
    echo "flo - GitHub Issue Flow Tool"
    echo ""
    echo "Usage: flo <command> [arguments]"
    echo "       flo <issue-number> [--zed] [--claude]"
    echo ""
    echo "Core Commands:"
    echo "  <number>                     Work on GitHub issue (create/navigate to worktree)"
    echo "  create, c <name> [<branch>]  Create a new worktree"
    echo "  rm, remove, r <name>         Remove a worktree"
    echo "  cd <name>                    Change to worktree directory"
    echo "  cd <project>/<name>          Change to worktree in another project"
    echo ""
    echo "Workflow Commands:"
    echo "  pr [create|open|status]      Manage pull requests"
    echo "  issues, i                    List repository issues with worktree status"
    echo "  sync                         Update caches and clean merged PRs"
    echo "  claude <name>                Start Claude in worktree with context"
    echo "  zed, z [<name>]              Open worktree in Zed editor"
    echo ""
    echo "Browse Commands:"
    echo "  list, ls, l [--all]          List worktrees (contextual defaults)"
    echo "  status, s [--project <name>] Show detailed status (contextual)"
    echo "  projects, p                  List all projects with worktrees"
    echo ""
    echo "Options:"
    echo "  --help, help, h              Show this help"
    echo "  --all                        Show all projects (for list/status)"
    echo "  --project <name>             Filter by project (all = all projects)"
    echo "  --zed                        Open in Zed editor"
    echo "  --claude                     Start Claude with context"
    echo ""
    echo "Environment Variables:"
    echo "  FLO_BASE_DIR      Root directory for all projects (default: ~/worktrees)"
    echo "  FLO_PROJECT_NAME  Override auto-detected project name"
    echo "  FLO_BRANCH_PREFIX Branch prefix for new worktrees (default: claude/)"
    echo "  FLO_ISSUE_PREFIX  Issue branch prefix (default: issue/)"
    echo "  FLO_CACHE_TTL     Cache lifetime in minutes (default: 30)"
    echo "  FLO_AUTO_CLOSE_PR Auto-close PR on worktree removal (default: true)"
    echo "  FLO_CLAUDE_PROMPT Custom Claude prompt template"
    echo ""
    echo "Examples:"
    echo "  flo 123                      Work on issue #123"
    echo "  flo 123 --zed --claude       Work on issue #123, open Zed and Claude"
    echo "  flo create feature-x         Create worktree (uses existing branch or creates new)"
    echo "  flo create feature-x main    Create worktree with new branch from 'main'"
    echo "  flo cd project/feature       Navigate to worktree in another project"
    echo "  flo list                     List worktrees (current project or all)"
    echo "  flo status --project all     Show status across all projects"
    echo "  flo pr create                Create PR for current worktree"
    echo ""
    echo "For help on specific commands, use: flo <command> --help"
end

function __flo_help_claude
    echo "flo claude - Start Claude Code with worktree context"
    echo ""
    echo "Usage: flo claude [<worktree-name>]"
    echo "       flo claude <project>/<worktree-name>"
    echo ""
    echo "Description:"
    echo "  Opens Claude Code in the specified worktree with context about the current"
    echo "  issue, PR status, and project information. For issue worktrees, it includes"
    echo "  the issue details and generates an optimized prompt."
    echo ""
    echo "  When run without arguments inside a flo worktree, it uses the current worktree."
    echo ""
    echo "Arguments:"
    echo "  <worktree-name>          Name of the worktree in current project (optional)"
    echo "  <project>/<name>         Worktree in a specific project"
    echo ""
    echo "Context Files:"
    echo "  CLAUDE.local.md          Human-readable context for Claude"
    echo "  .flo/cache/issue.json    Full issue data (for issue worktrees)"
    echo "  .flo/cache/comments.json Issue comments (for issue worktrees)"
    echo ""
    echo "Examples:"
    echo "  flo claude               Start Claude in current worktree"
    echo "  flo claude issue/123     Start Claude for issue #123"
    echo "  flo claude feature-x     Start Claude for feature worktree"
    echo "  flo claude proj/feat     Start Claude for worktree in another project"
    echo ""
    echo "Environment:"
    echo "  FLO_CLAUDE_PROMPT        Custom prompt template with {{issue_number}} and {{issue_title}}"
end

function __flo_help_create
    echo "flo create - Create a new worktree"
    echo ""
    echo "Usage: flo create <name> [<source-branch>]"
    echo ""
    echo "Description:"
    echo "  Creates a new Git worktree with smart branch detection. If a branch exists"
    echo "  locally or remotely, it will be used. Otherwise, a new branch is created."
    echo ""
    echo "Arguments:"
    echo "  <name>              Worktree name (also used as branch name with prefix)"
    echo "  <source-branch>     Optional: Create new branch from this source"
    echo ""
    echo "Branch Naming:"
    echo "  - Regular worktrees: \$FLO_BRANCH_PREFIX<name> (default: claude/<name>)"
    echo "  - Issue worktrees: issue/<number> (when name matches issue pattern)"
    echo ""
    echo "Examples:"
    echo "  flo create feature-x        Use existing branch or create from HEAD"
    echo "  flo create feature-x main   Create new branch from main"
    echo "  flo create issue/123        Create issue worktree (special naming)"
end

function __flo_help_list
    echo "flo list - List worktrees"
    echo ""
    echo "Usage: flo list [--all]"
    echo ""
    echo "Description:"
    echo "  Lists worktrees with contextual defaults:"
    echo "  - In a git repo: Shows current project only"
    echo "  - Outside git repo: Shows all projects"
    echo ""
    echo "Options:"
    echo "  --all    Show worktrees across all projects"
    echo ""
    echo "Output:"
    echo "  → marker indicates current worktree"
    echo "  Shows branch name for each worktree"
    echo "  Groups by project when showing all"
end

function __flo_help_status
    echo "flo status - Show detailed status information"
    echo ""
    echo "Usage: flo status [--project <name>]"
    echo ""
    echo "Description:"
    echo "  Shows contextual status information:"
    echo "  - In a worktree: Detailed worktree status"
    echo "  - In main repo: All project worktrees"
    echo "  - Outside git: Must specify --project"
    echo ""
    echo "Options:"
    echo "  --project <name>    Show status for specific project"
    echo "  --project all       Show status across all projects"
    echo ""
    echo "Worktree Status Includes:"
    echo "  - Branch information and sync status"
    echo "  - Issue details (for issue worktrees)"
    echo "  - PR status and review state"
    echo "  - Git status summary"
end

function __flo_help_pr
    echo "flo pr - Manage pull requests"
    echo ""
    echo "Usage: flo pr [subcommand]"
    echo ""
    echo "Subcommands:"
    echo "  create, c    Create a new pull request"
    echo "  open, o      Open PR in browser (creates if needed)"
    echo "  status, s    Show PR status for current branch"
    echo "  list, l      List all open PRs in repository"
    echo ""
    echo "Default: Shows status if no subcommand given"
    echo ""
    echo "Examples:"
    echo "  flo pr              Show current branch PR status"
    echo "  flo pr create       Create PR with smart defaults"
    echo "  flo pr open         Open PR in browser"
end

function __flo_help_remove
    echo "flo remove - Remove a worktree"
    echo ""
    echo "Usage: flo rm <name>"
    echo "       flo remove <name>"
    echo ""
    echo "Description:"
    echo "  Removes a Git worktree with PR awareness. If the worktree has an open PR,"
    echo "  you'll be prompted to close it (configurable via FLO_AUTO_CLOSE_PR)."
    echo ""
    echo "Arguments:"
    echo "  <name>              Worktree name in current project"
    echo "  <project>/<name>    Worktree in specific project"
    echo ""
    echo "Options:"
    echo "  Multiple worktrees can be specified"
    echo ""
    echo "Environment:"
    echo "  FLO_AUTO_CLOSE_PR   Prompt to close associated PRs (default: true)"
end

function __flo_issue --argument-names issue_number
    # Parse remaining arguments for flags
    set -l do_zed false
    set -l do_claude false

    for arg in $argv
        switch $arg
            case --zed
                set do_zed true
            case --claude
                set do_claude true
        end
    end

    # Check if we're in a git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        set_color red
        echo "Error: Not in a git repository"
        set_color normal
        return 1
    end

    # Get project context
    set -l project_name (__flo_get_project_name)
    if test -z "$project_name"
        set_color red
        echo "Error: Could not determine project name"
        set_color normal
        return 1
    end

    set -l base_root (test -n "$FLO_BASE_DIR"; and echo "$FLO_BASE_DIR"; or echo "$HOME/worktrees")
    set -l base_dir "$base_root/$project_name"
    set -l issue_prefix (test -n "$FLO_ISSUE_PREFIX"; and echo "$FLO_ISSUE_PREFIX"; or echo "issue/")
    set -l worktree_name "$issue_prefix$issue_number"
    set -l worktree_path "$base_dir/$worktree_name"

    # Check if issue exists via gh
    echo "Checking issue #$issue_number..."
    set -l issue_data (gh issue view $issue_number --json number,title,state,body,labels,assignees 2>/dev/null)
    if test $status -ne 0
        set_color red
        echo "Error: Issue #$issue_number not found or gh CLI error"
        set_color normal
        return 1
    end

    # Parse issue data
    set -l issue_title (echo $issue_data | jq -r '.title')
    set -l issue_state (echo $issue_data | jq -r '.state')

    # Show issue info
    set_color green
    echo "Issue #$issue_number: $issue_title"
    set_color normal
    echo "State: $issue_state"
    echo ""

    # Check if worktree already exists
    if test -d "$worktree_path"
        echo "Navigating to existing worktree..."
        cd "$worktree_path"

        # Update context files
        __flo_update_issue_context $worktree_path $issue_number $issue_data
    else
        # Create new worktree
        echo "Creating new worktree..."

        # Ensure base directory exists
        mkdir -p "$base_dir"; or begin
            set_color red
            echo "Error: Failed to create base directory: $base_dir"
            set_color normal
            return 1
        end

        # Create worktree
        git worktree add "$worktree_path" -b "$worktree_name"; or begin
            set_color red
            echo "Error: Failed to create worktree"
            set_color normal
            return 1
        end

        echo "Created worktree at: $worktree_path"
        cd "$worktree_path"

        # Create initial context files
        __flo_create_issue_context $worktree_path $issue_number $issue_data
    end

    # Handle flags
    if test $do_zed = true
        zed .
    end

    if test $do_claude = true
        # Create context-aware prompt
        set -l prompt "I'm working on issue #$issue_number: '$issue_title' in repository $project_name on branch '$worktree_name'. "
        set -l pr_info (gh pr list --head $worktree_name --json number,state --jq '.[0]' 2>/dev/null)
        if test -n "$pr_info"
            set -l pr_number (echo $pr_info | jq -r '.number')
            set -l pr_state (echo $pr_info | jq -r '.state')
            set prompt "$prompt There is PR #$pr_number ($pr_state) for this issue. "
        else
            set prompt "$prompt No PR exists yet. "
        end
        set prompt "$prompt The issue details are in CLAUDE.local.md and full data in .flo/cache/. How can I help with this issue?"

        # Allow custom prompt override
        if test -n "$FLO_CLAUDE_PROMPT"
            set prompt (string replace -a "{{issue_number}}" "$issue_number" $FLO_CLAUDE_PROMPT | string replace -a "{{issue_title}}" "$issue_title")
        end

        claude "$prompt"
    end
end

function __flo_create_issue_context --argument-names worktree_path issue_number issue_data
    # Create .flo/cache directory
    mkdir -p "$worktree_path/.flo/cache"

    # Save raw issue data
    echo $issue_data >"$worktree_path/.flo/cache/issue.json"

    # Get issue comments
    gh issue view $issue_number --comments --json comments | jq '.comments' >"$worktree_path/.flo/cache/comments.json" 2>/dev/null

    # Create metadata
    echo "{\"updated\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"version\": \"1.0\"}" >"$worktree_path/.flo/cache/metadata.json"

    # Create CLAUDE.local.md
    __flo_generate_claude_context $worktree_path $issue_number $issue_data >"$worktree_path/CLAUDE.local.md"

    # Ensure .gitignore entries
    __flo_ensure_gitignore $worktree_path

    set_color green
    echo "Created context files in .flo/cache/ and CLAUDE.local.md"
    set_color normal
end

function __flo_update_issue_context --argument-names worktree_path issue_number issue_data
    # Check cache age
    set -l cache_ttl (test -n "$FLO_CACHE_TTL"; and echo "$FLO_CACHE_TTL"; or echo "30")
    set -l should_update false

    if test -f "$worktree_path/.flo/cache/metadata.json"
        set -l last_update (cat "$worktree_path/.flo/cache/metadata.json" | jq -r '.updated' 2>/dev/null)
        if test -n "$last_update"
            set -l age_minutes (math (date +%s) - (date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_update" +%s 2>/dev/null || echo 0) / 60)
            if test $age_minutes -gt $cache_ttl
                set should_update true
            end
        else
            set should_update true
        end
    else
        set should_update true
    end

    if test $should_update = true
        echo "Updating context files..."
        __flo_create_issue_context $worktree_path $issue_number $issue_data
    end
end

function __flo_generate_claude_context --argument-names worktree_path issue_number issue_data
    set -l title (echo $issue_data | jq -r '.title')
    set -l state (echo $issue_data | jq -r '.state')
    set -l body (echo $issue_data | jq -r '.body // "No description"')
    set -l labels (echo $issue_data | jq -r '.labels[].name' | string join ', ')

    echo "# Issue #$issue_number: $title"
    echo ""
    echo "## Status"
    echo "- State: $state"
    if test -n "$labels"
        echo "- Labels: $labels"
    end

    # Check for PR
    set -l pr_info (gh pr list --head "issue/$issue_number" --json number,state,url --jq '.[0]' 2>/dev/null)
    if test -n "$pr_info"
        set -l pr_number (echo $pr_info | jq -r '.number')
        set -l pr_state (echo $pr_info | jq -r '.state')
        set -l pr_url (echo $pr_info | jq -r '.url')
        echo "- PR: #$pr_number ($pr_state)"
    end

    echo ""
    echo "## Description"
    echo "$body"
    echo ""
    echo "## Files"
    echo "- Full issue data: .flo/cache/issue.json"
    echo "- Comments: .flo/cache/comments.json"
    if test -n "$pr_info"
        echo "- PR data: .flo/cache/pr.json"
    end
    echo ""
    echo "## Context"
    echo "Created by flo for issue #$issue_number"
    set -l repo_info (gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
    if test -n "$repo_info"
        echo "Repository: $repo_info"
    end
end

function __flo_ensure_gitignore --argument-names worktree_path
    set -l gitignore_path "$worktree_path/.gitignore"
    set -l needs_update false

    # Check if entries exist
    if test -f "$gitignore_path"
        if not string match -q '*CLAUDE.local.md*' <"$gitignore_path"
            set needs_update true
        end
        if not string match -q '*.flo/*' <"$gitignore_path"
            set needs_update true
        end
    else
        set needs_update true
    end

    if test $needs_update = true
        echo "" >>"$gitignore_path"
        echo "# flo context files" >>"$gitignore_path"
        if not string match -q '*CLAUDE.local.md*' <"$gitignore_path"
            echo "CLAUDE.local.md" >>"$gitignore_path"
        end
        if not string match -q '*.flo/*' <"$gitignore_path"
            echo ".flo/" >>"$gitignore_path"
        end
        echo "Updated .gitignore with flo entries"
    end
end

function __flo_create --argument-names base_dir branch_prefix issue_prefix
    set -e argv[1..3]

    # Check for help flag
    if contains -- --help $argv
        __flo_help_create
        return 0
    end

    # Ensure base directory exists
    if not test -d "$base_dir"
        mkdir -p "$base_dir"; or begin
            set_color red
            echo "Error: Failed to create base directory: $base_dir"
            set_color normal
            return 1
        end
    end

    if test (count $argv) -eq 0
        set_color red
        echo "Error: No worktree name provided"
        set_color normal
        echo "Usage: flo create <name> [<source-branch>]"
        echo "Run 'flo create --help' for more information"
        return 1
    end

    for i in (seq (count $argv))
        set -l name $argv[$i]
        set -l source_branch ""

        # Check if next argument is a source branch (only for single worktree creation)
        if test (count $argv) -eq 2 -a $i -eq 1
            set source_branch $argv[2]
            set i (math $i + 1)
        end

        # Validate name
        if not __flo_validate_name $name
            continue
        end

        set -l worktree_path "$base_dir/$name"

        # Determine branch prefix based on name pattern
        set -l branch_name
        if string match -qr '^issue/\d+$' $name
            # Already has issue prefix
            set branch_name $name
        else
            # Use regular branch prefix
            set branch_name "$branch_prefix$name"
        end

        # Check if worktree already exists
        if test -d "$worktree_path"
            set_color yellow
            echo "Warning: Worktree '$name' already exists"
            set_color normal
            continue
        end

        # Create worktree
        set_color green
        echo "Creating worktree: $name"
        set_color normal

        # Check if branch already exists
        set -l branch_exists (git show-ref --verify --quiet refs/heads/$branch_name 2>/dev/null; and echo true; or echo false)
        set -l remote_branch_exists false
        if test $branch_exists = false
            # Check for remote branch
            set -l remote_refs (git ls-remote --heads origin $branch_name 2>/dev/null | wc -l | string trim)
            if test $remote_refs -gt 0
                set remote_branch_exists true
            end
        end

        if test -n "$source_branch"
            # Creating from a specific source branch - always create new branch
            git worktree add "$worktree_path" -b "$branch_name" "$source_branch"; or begin
                set_color red
                echo "Error: Failed to create worktree '$name' from branch '$source_branch'"
                set_color normal
                return 1
            end
            echo "  Created new branch from: $source_branch"
        else if test $branch_exists = true
            # Use existing local branch
            echo "  Using existing local branch: $branch_name"
            git worktree add "$worktree_path" "$branch_name"; or begin
                set_color red
                echo "Error: Failed to create worktree '$name' with existing branch '$branch_name'"
                set_color normal
                return 1
            end
        else if test $remote_branch_exists = true
            # Create from remote branch
            echo "  Creating from remote branch: origin/$branch_name"
            git worktree add "$worktree_path" "$branch_name"; or begin
                set_color red
                echo "Error: Failed to create worktree '$name' from remote branch"
                set_color normal
                return 1
            end
        else
            # Create new branch from current HEAD
            echo "  Creating new branch from HEAD"
            git worktree add "$worktree_path" -b "$branch_name"; or begin
                set_color red
                echo "Error: Failed to create worktree '$name'"
                set_color normal
                return 1
            end
        end

        echo "  Path: $worktree_path"
        echo "  Branch: $branch_name"
    end
end

function __flo_remove --argument-names base_root in_git_repo project_name
    set -e argv[1..3]

    # Check for help flag
    if contains -- --help $argv
        __flo_help_remove
        return 0
    end

    if test (count $argv) -eq 0
        set_color red
        echo "Error: No worktree name provided"
        set_color normal
        echo "Usage: flo rm <name>"
        echo "Run 'flo remove --help' for more information"
        return 1
    end

    for name in $argv
        set -l worktree_path ""

        # Determine worktree path
        if string match -q '*/*' $name
            # Full project/name path
            set worktree_path "$base_root/$name"
        else if test $in_git_repo = true -a -n "$project_name"
            # In git repo, use current project
            set worktree_path "$base_root/$project_name/$name"
        else
            set_color red
            echo "Error: Not in a git repository. Use 'flo rm <project>/<name>' format"
            set_color normal
            return 1
        end

        if not test -d "$worktree_path"
            set_color yellow
            echo "Warning: Worktree '$name' does not exist"
            set_color normal
            continue
        end

        # Check for associated PR
        set -l branch (git -C "$worktree_path" branch --show-current 2>/dev/null)
        set -l pr_data ""
        set -l pr_number ""
        set -l pr_state ""

        if test -n "$branch"
            set pr_data (gh pr list --head $branch --json number,state,title --jq '.[0]' 2>/dev/null)
            if test -n "$pr_data" -a "$pr_data" != null
                set pr_number (echo $pr_data | jq -r '.number')
                set pr_state (echo $pr_data | jq -r '.state')
                set -l pr_title (echo $pr_data | jq -r '.title')

                echo ""
                set_color cyan
                echo "Associated PR #$pr_number: $pr_title"
                echo "State: $pr_state"
                set_color normal
            end
        end

        # Confirm removal
        set_color yellow
        printf "Remove worktree '%s'? [y/N] " $name
        set_color normal
        read -l reply

        switch $reply
            case y Y yes YES Yes
                # Handle PR if exists and is open
                if test -n "$pr_number" -a "$pr_state" = OPEN
                    set -l auto_close_pr (test -n "$FLO_AUTO_CLOSE_PR"; and echo "$FLO_AUTO_CLOSE_PR"; or echo "true")

                    if test "$auto_close_pr" = true
                        set_color yellow
                        printf "Close associated PR #$pr_number? [Y/n] "
                        set_color normal
                        read -l pr_reply

                        if test -z "$pr_reply" -o "$pr_reply" = y -o "$pr_reply" = Y
                            echo "Closing PR #$pr_number..."
                            gh pr close $pr_number
                            if test $status -eq 0
                                set_color green
                                echo "✓ PR closed"
                                set_color normal
                            else
                                set_color red
                                echo "✗ Failed to close PR"
                                set_color normal
                            end
                        end
                    end
                end

                # Remove worktree
                set_color green
                echo "Removing worktree: $name"
                set_color normal
                git worktree remove "$worktree_path"; or begin
                    set_color red
                    echo "Error: Failed to remove worktree '$name'"
                    echo "Try: git worktree remove --force '$worktree_path'"
                    set_color normal
                    return 1
                end
            case '*'
                echo "Skipping: $name"
        end
    end
end

function __flo_cd --argument-names base_root in_git_repo project_name
    set -e argv[1..3]

    if test (count $argv) -ne 1
        set_color red
        echo "Error: Provide exactly one worktree name"
        set_color normal
        echo "Usage: flo cd <name> or flo cd <project>/<name>"
        return 1
    end

    set -l target $argv[1]
    set -l worktree_path ""

    # Check if target contains a project separator
    if string match -q '*/*' $target
        # Cross-project navigation
        set -l parts (string split '/' $target)
        set -l project $parts[1]
        set -l name $parts[2]
        set worktree_path "$base_root/$project/$name"
    else if test $in_git_repo = true -a -n "$project_name"
        # Same project navigation
        set worktree_path "$base_root/$project_name/$target"
    else
        # Not in git repo and no project specified
        set_color red
        echo "Error: Not in a git repository. Use 'flo cd <project>/<name>' format"
        set_color normal
        __flo_list $base_root false "" --all
        return 1
    end

    if not test -d "$worktree_path"
        set_color red
        echo "Error: Worktree '$target' does not exist"
        set_color normal
        __flo_list $base_root $in_git_repo $project_name --all
        return 1
    end

    cd "$worktree_path"
    set_color green
    echo "Changed to worktree: $target"
    set_color normal
end

function __flo_claude --argument-names base_root in_git_repo project_name branch_prefix issue_prefix
    set -e argv[1..5]

    # Check for help flag
    if contains -- --help $argv
        __flo_help_claude
        return 0
    end

    # If no arguments, check if we're in a worktree
    if test (count $argv) -eq 0
        set -l current_path (pwd)
        # Check if we're in a flo worktree
        if string match -q "$base_root/*/*" $current_path
            # Extract project and worktree name from current path
            set -l path_parts (string split / $current_path)
            set -l base_parts (string split / $base_root)
            set -l idx (math (count $base_parts) + 1)
            if test (count $path_parts) -gt $idx
                set project_name $path_parts[$idx]
                set -l name $path_parts[(math $idx + 1)]
                set -l worktree_path "$base_root/$project_name/$name"
                # Jump to the worktree workflow section
                cd "$worktree_path"

                # Check if this is an issue worktree
                if string match -qr '^issue/(\d+)$' $name
                    set -l issue_number (string replace -r '^issue/(\d+)$' '$1' $name)

                    # Update context if needed
                    set -l issue_data (gh issue view $issue_number --json number,title,state,body,labels,assignees 2>/dev/null)
                    if test -n "$issue_data"
                        __flo_update_issue_context $worktree_path $issue_number $issue_data
                    end

                    # Create context-aware prompt
                    set -l issue_title (echo $issue_data | jq -r '.title')
                    set -l prompt "I'm working on issue #$issue_number: '$issue_title' in repository $project_name on branch '$name'. "

                    set -l pr_info (gh pr list --head $name --json number,state --jq '.[0]' 2>/dev/null)
                    if test -n "$pr_info" -a "$pr_info" != null
                        set -l pr_number (echo $pr_info | jq -r '.number')
                        set -l pr_state (echo $pr_info | jq -r '.state')
                        set prompt "$prompt There is PR #$pr_number ($pr_state) for this issue. "
                    else
                        set prompt "$prompt No PR exists yet. "
                    end
                    set prompt "$prompt The issue details are in CLAUDE.local.md and full data in .flo/cache/. How can I help with this issue?"

                    # Allow custom prompt override
                    if test -n "$FLO_CLAUDE_PROMPT"
                        set prompt (string replace -a "{{issue_number}}" "$issue_number" $FLO_CLAUDE_PROMPT | string replace -a "{{issue_title}}" "$issue_title")
                    end

                    claude "$prompt"
                else
                    # For non-issue worktrees, create a simple context file
                    if not test -f "$worktree_path/CLAUDE.local.md"
                        echo "# Worktree: $name" >"$worktree_path/CLAUDE.local.md"
                        echo "" >>"$worktree_path/CLAUDE.local.md"
                        echo "## Project: $project_name" >>"$worktree_path/CLAUDE.local.md"
                        echo "" >>"$worktree_path/CLAUDE.local.md"
                        echo "## Branch: $name" >>"$worktree_path/CLAUDE.local.md"
                        echo "" >>"$worktree_path/CLAUDE.local.md"
                        echo "Created by flo for worktree development" >>"$worktree_path/CLAUDE.local.md"

                        __flo_ensure_gitignore $worktree_path
                    end

                    # Start claude with basic context
                    set -l prompt "I'm working in worktree '$name' for project $project_name. How can I help?"
                    claude "$prompt"
                end
                return
            end
        end
        # Not in a worktree
        set_color red
        echo "Error: Not in a flo worktree. Provide a worktree name or navigate to one."
        set_color normal
        echo "Usage: flo claude [<name>]"
        echo "Run 'flo claude --help' for more information"
        return 1
    end

    if test (count $argv) -ne 1
        set_color red
        echo "Error: Provide exactly one worktree name"
        set_color normal
        echo "Usage: flo claude [<name>]"
        echo "Run 'flo claude --help' for more information"
        return 1
    end

    set -l name $argv[1]
    set -l worktree_path ""

    # Determine worktree path
    if string match -q '*/*' $name
        set worktree_path "$base_root/$name"
    else if test $in_git_repo = true -a -n "$project_name"
        set worktree_path "$base_root/$project_name/$name"
    else
        set_color red
        echo "Error: Not in a git repository. Use 'flo claude <project>/<name>' format"
        set_color normal
        return 1
    end

    # Create worktree if it doesn't exist
    if not test -d "$worktree_path"
        if test $in_git_repo = false
            set_color red
            echo "Error: Cannot create worktree - not in a git repository"
            set_color normal
            return 1
        end

        set_color yellow
        printf "Worktree '%s' doesn't exist. Create it now? [y/N] " $name
        set_color normal
        read -l reply

        switch $reply
            case y Y yes YES Yes
                __flo_create "$base_root/$project_name" $branch_prefix $issue_prefix $name; or return 1
            case '*'
                echo "Aborted."
                return 1
        end
    end

    # Create/update context files
    cd "$worktree_path"

    # Check if this is an issue worktree
    if string match -qr '^issue/(\d+)$' $name
        set -l issue_number (string replace -r '^issue/(\d+)$' '$1' $name)

        # Update context if needed
        set -l issue_data (gh issue view $issue_number --json number,title,state,body,labels,assignees 2>/dev/null)
        if test -n "$issue_data"
            __flo_update_issue_context $worktree_path $issue_number $issue_data
        end

        # Create context-aware prompt
        set -l issue_title (echo $issue_data | jq -r '.title')
        set -l prompt "I'm working on issue #$issue_number: '$issue_title' in repository $project_name on branch '$name'. "

        set -l pr_info (gh pr list --head $name --json number,state --jq '.[0]' 2>/dev/null)
        if test -n "$pr_info" -a "$pr_info" != null
            set -l pr_number (echo $pr_info | jq -r '.number')
            set -l pr_state (echo $pr_info | jq -r '.state')
            set prompt "$prompt There is PR #$pr_number ($pr_state) for this issue. "
        else
            set prompt "$prompt No PR exists yet. "
        end
        set prompt "$prompt The issue details are in CLAUDE.local.md and full data in .flo/cache/. How can I help with this issue?"

        # Allow custom prompt override
        if test -n "$FLO_CLAUDE_PROMPT"
            set prompt (string replace -a "{{issue_number}}" "$issue_number" $FLO_CLAUDE_PROMPT | string replace -a "{{issue_title}}" "$issue_title")
        end

        claude "$prompt"
    else
        # For non-issue worktrees, create a simple context file
        if not test -f "$worktree_path/CLAUDE.local.md"
            echo "# Worktree: $name" >"$worktree_path/CLAUDE.local.md"
            echo "" >>"$worktree_path/CLAUDE.local.md"
            echo "## Project: $project_name" >>"$worktree_path/CLAUDE.local.md"
            echo "" >>"$worktree_path/CLAUDE.local.md"
            echo "## Branch: $name" >>"$worktree_path/CLAUDE.local.md"
            echo "" >>"$worktree_path/CLAUDE.local.md"
            echo "Created by flo for worktree development" >>"$worktree_path/CLAUDE.local.md"

            __flo_ensure_gitignore $worktree_path
        end

        # Start claude with basic context
        set -l prompt "I'm working in worktree '$name' for project $project_name. How can I help?"
        claude "$prompt"
    end
end

function __flo_list --argument-names base_root in_git_repo project_name
    set -e argv[1..3]

    # Check for help flag
    if contains -- --help $argv
        __flo_help_list
        return 0
    end

    # Determine default behavior
    set -l show_all false
    if test $in_git_repo = false
        # Not in git repo - default to showing all
        set show_all true
    else if contains -- --all $argv
        set show_all true
    end

    if not test -d "$base_root"
        # Create base directory if it doesn't exist
        mkdir -p "$base_root"
        set_color yellow
        echo "No worktrees found"
        echo ""
        echo "Flo manages worktrees in: $base_root/<project>/<worktree-name>"
        echo "Use 'flo create <name>' to create your first worktree"
        set_color normal
        return 0
    end

    set -l current_path (pwd)
    set -l found_any false

    if test $show_all = true
        echo "All worktrees:"
    else
        echo "Worktrees for project: $project_name"
    end
    echo ""

    if test $show_all = true
        # Show all projects
        for project_dir in $base_root/*
            if test -d "$project_dir"
                set -l proj_name (basename $project_dir)
                set -l has_worktrees false

                # Check if project has worktrees
                for worktree in $project_dir/*
                    if test -d "$worktree"
                        if test $has_worktrees = false
                            set has_worktrees true
                            set_color cyan
                            echo "[$proj_name]"
                            set_color normal
                        end

                        set -l name (basename $worktree)
                        set -l is_current (test "$worktree" = "$current_path"; and echo true; or echo false)

                        # Try to get branch info
                        set -l branch_info ""
                        if test -f "$worktree/.git"
                            set -l branch (git -C "$worktree" branch --show-current 2>/dev/null)
                            if test -n "$branch"
                                set branch_info " (branch: $branch)"
                            end
                        end

                        if test $is_current = true
                            set_color green
                            echo "  → $name$branch_info"
                            set_color normal
                        else
                            echo "    $name$branch_info"
                        end
                        set found_any true
                    end
                end
            end
        end
    else
        # Show current project only
        if test -d "$base_root/$project_name"
            for worktree in "$base_root/$project_name"/*
                if test -d "$worktree"
                    set found_any true
                    set -l name (basename $worktree)
                    set -l is_current (test "$worktree" = "$current_path"; and echo true; or echo false)

                    # Try to get branch info
                    set -l branch_info ""
                    if test -f "$worktree/.git"
                        set -l branch (git -C "$worktree" branch --show-current 2>/dev/null)
                        if test -n "$branch"
                            set branch_info " (branch: $branch)"
                        end
                    end

                    if test $is_current = true
                        set_color green
                        echo "→ $name$branch_info"
                        set_color normal
                    else
                        echo "  $name$branch_info"
                    end
                end
            end
        end
    end

    if not test $found_any = true
        set_color yellow
        if test $show_all = true
            echo "No worktrees found"
            echo ""
            echo "Flo manages worktrees in: $base_root/<project>/<worktree-name>"
        else
            echo "No worktrees found for project: $project_name"
            echo ""
            echo "Worktrees would be in: $base_root/$project_name/"
        end
        echo "Use 'flo create <name>' to create a worktree"
        set_color normal
    end
end

function __flo_status --argument-names base_root in_git_repo project_name
    set -e argv[1..3]

    # Check for help flag
    if contains -- --help $argv
        __flo_help_status
        return 0
    end

    # Parse --project flag
    set -l target_project ""
    set -l remaining_args

    # Only process if there are arguments
    if test (count $argv) -gt 0
        set -l skip_next false
        for i in (seq (count $argv))
            if test $skip_next = true
                set skip_next false
                continue
            end

            if test "$argv[$i]" = --project
                if test (math $i + 1) -le (count $argv)
                    set target_project $argv[(math $i + 1)]
                    set skip_next true
                end
            else
                set remaining_args $remaining_args $argv[$i]
            end
        end
    end

    # Determine what to show based on context
    if test -n "$target_project"
        if test "$target_project" = all
            __flo_status_all_projects $base_root
        else
            __flo_status_project $base_root $target_project
        end
    else if test $in_git_repo = true
        set -l current_path (pwd)
        # Check if we're in a worktree
        if string match -q "$base_root/*/*/*" $current_path
            # In a worktree - show detailed status
            __flo_status_worktree $current_path
        else
            # In main repo - show all project worktrees
            __flo_status_project $base_root $project_name
        end
    else
        set_color red
        echo "Error: Not in a git repository. Use 'flo status --project <name>' or 'flo status --project all'"
        set_color normal
        return 1
    end
end

function __flo_status_worktree --argument-names worktree_path
    set -l worktree_name (basename $worktree_path)
    set -l project_name (basename (dirname $worktree_path))

    # Header
    set_color cyan
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Worktree: $worktree_name"
    echo "Project: $project_name"
    echo "Path: $worktree_path"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    set_color normal
    echo ""

    # Git information
    cd "$worktree_path"
    set -l current_branch (git branch --show-current)
    set -l upstream (git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)

    echo "Branch: $current_branch"
    if test -n "$upstream"
        echo "Tracking: $upstream"

        # Get ahead/behind info
        set -l ahead_behind (git rev-list --left-right --count HEAD...$upstream 2>/dev/null)
        if test -n "$ahead_behind"
            set -l ahead (echo $ahead_behind | cut -f1)
            set -l behind (echo $ahead_behind | cut -f2)
            if test $ahead -gt 0 -o $behind -gt 0
                echo -n "Status: "
                if test $ahead -gt 0
                    set_color green
                    echo -n "$ahead ahead"
                    set_color normal
                end
                if test $ahead -gt 0 -a $behind -gt 0
                    echo -n ", "
                end
                if test $behind -gt 0
                    set_color red
                    echo -n "$behind behind"
                    set_color normal
                end
                echo ""
            end
        end
    end
    echo ""

    # Check if this is an issue worktree
    if string match -qr '^issue/(\d+)$' $worktree_name
        set -l issue_number (string replace -r '^issue/(\d+)$' '$1' $worktree_name)

        # Show issue info
        set_color green
        echo "Issue Information:"
        set_color normal

        # Check cache
        if test -f "$worktree_path/.flo/cache/issue.json"
            set -l issue_data (cat "$worktree_path/.flo/cache/issue.json")
            set -l issue_title (echo $issue_data | jq -r '.title')
            set -l issue_state (echo $issue_data | jq -r '.state')
            set -l labels (echo $issue_data | jq -r '.labels[].name' | string join ', ')

            echo "  #$issue_number: $issue_title"
            echo "  State: $issue_state"
            if test -n "$labels"
                echo "  Labels: $labels"
            end

            # Cache age
            if test -f "$worktree_path/.flo/cache/metadata.json"
                set -l updated (cat "$worktree_path/.flo/cache/metadata.json" | jq -r '.updated')
                echo "  Cache: Updated $updated"
            end
        else
            echo "  #$issue_number (no cache - run 'flo sync')"
        end
        echo ""

        # Check for PR
        set -l pr_data (gh pr list --head $current_branch --json number,state,url --jq '.[0]' 2>/dev/null)
        if test -n "$pr_data" -a "$pr_data" != null
            set_color green
            echo "Pull Request:"
            set_color normal
            set -l pr_number (echo $pr_data | jq -r '.number')
            set -l pr_state (echo $pr_data | jq -r '.state')
            echo "  PR #$pr_number (State: $pr_state)"
        end
        echo ""
    end

    # Git status
    set_color green
    echo "Git Status:"
    set_color normal
    git status -sb | head -10

    set -l status_lines (git status -sb | wc -l)
    if test $status_lines -gt 10
        echo "  ... and "(math $status_lines - 10)" more lines"
    end
end

function __flo_status_project --argument-names base_root project_name
    set_color cyan
    echo "Project: $project_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    set_color normal
    echo ""

    if not test -d "$base_root/$project_name"
        set_color yellow
        echo "No worktrees found"
        set_color normal
        return
    end

    # List worktrees with status
    for worktree_dir in "$base_root/$project_name"/*
        if test -d "$worktree_dir"
            set -l name (basename $worktree_dir)
            set -l branch (git -C "$worktree_dir" branch --show-current 2>/dev/null)

            # Check git status
            set -l status_summary ""
            if test -n "$branch"
                set -l changes (git -C "$worktree_dir" status --porcelain 2>/dev/null | wc -l | string trim)
                if test $changes -gt 0
                    set status_summary " ($changes changes)"
                end

                # Check for PR
                set -l pr_info (gh pr list --head $branch --json number,state --jq '.[0]' 2>/dev/null)
                if test -n "$pr_info" -a "$pr_info" != null
                    set -l pr_num (echo $pr_info | jq -r '.number')
                    set -l pr_state (echo $pr_info | jq -r '.state')
                    set status_summary "$status_summary PR #$pr_num ($pr_state)"
                end
            end

            # Check if issue worktree
            set -l issue_info ""
            if string match -qr '^issue/(\d+)$' $name
                set -l issue_num (string replace -r '^issue/(\d+)$' '$1' $name)
                set issue_info " Issue #$issue_num"
            end

            echo "• $name → $branch$issue_info$status_summary"
        end
    end
    echo ""
end

function __flo_status_all_projects --argument-names base_root
    set_color cyan
    echo "All Projects Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    set_color normal
    echo ""

    if not test -d "$base_root"
        # Create base directory if it doesn't exist
        mkdir -p "$base_root"
        set_color yellow
        echo "No projects found"
        echo ""
        echo "Flo manages worktrees in: $base_root/<project>/<worktree-name>"
        echo "Use 'flo create <name>' to create your first worktree"
        set_color normal
        return
    end

    set -l total_worktrees 0
    set -l total_issues 0
    set -l total_prs 0

    for project_dir in "$base_root"/*
        if test -d "$project_dir"
            set -l project (basename $project_dir)
            set -l worktree_count 0
            set -l issue_count 0
            set -l pr_count 0

            # Count worktrees and gather stats
            for worktree in "$project_dir"/*
                if test -d "$worktree"
                    set worktree_count (math $worktree_count + 1)
                    set total_worktrees (math $total_worktrees + 1)

                    # Check if issue worktree
                    set -l wt_name (basename $worktree)
                    if string match -qr '^issue/\d+$' $wt_name
                        set issue_count (math $issue_count + 1)
                        set total_issues (math $total_issues + 1)
                    end

                    # Check for PR
                    set -l branch (git -C "$worktree" branch --show-current 2>/dev/null)
                    if test -n "$branch"
                        set -l has_pr (gh pr list --head $branch --json number --jq '.[0].number' 2>/dev/null)
                        if test -n "$has_pr"
                            set pr_count (math $pr_count + 1)
                            set total_prs (math $total_prs + 1)
                        end
                    end
                end
            end

            if test $worktree_count -gt 0
                set_color green
                echo -n "[$project] "
                set_color normal
                echo -n "$worktree_count worktrees"

                if test $issue_count -gt 0
                    echo -n ", $issue_count issues"
                end

                if test $pr_count -gt 0
                    echo -n ", $pr_count PRs"
                end

                echo ""
            end
        end
    end

    echo ""
    set_color cyan
    echo "Summary:"
    set_color normal
    echo "  Total worktrees: $total_worktrees"
    echo "  Issue worktrees: $total_issues"
    echo "  Active PRs: $total_prs"
end

function __flo_projects --argument-names base_root
    if not test -d "$base_root"
        # Create base directory if it doesn't exist
        mkdir -p "$base_root"
        set_color yellow
        echo "No projects found"
        echo ""
        echo "Flo manages worktrees in: $base_root/<project>/<worktree-name>"
        echo "Use 'flo create <name>' to create your first worktree"
        set_color normal
        return 0
    end

    echo "Projects with worktrees:"
    echo ""

    set -l found_any false
    for project_dir in $base_root/*
        if test -d "$project_dir"
            set -l project_name (basename $project_dir)
            set -l worktree_count 0

            # Count actual worktrees
            for worktree in $project_dir/*
                if test -d "$worktree"
                    set worktree_count (math $worktree_count + 1)
                end
            end

            if test $worktree_count -gt 0
                set found_any true
                set_color cyan
                echo "$project_name ($worktree_count worktrees)"
                set_color normal

                # List worktrees in this project
                for worktree in $project_dir/*
                    if test -d "$worktree"
                        set -l name (basename $worktree)
                        set -l branch (git -C $worktree branch --show-current 2>/dev/null; or echo "unknown")
                        echo "  - $name (branch: $branch)"
                    end
                end
                echo ""
            end
        end
    end

    if not test $found_any = true
        set_color yellow
        echo "  No projects with worktrees found"
        set_color normal
    end
end

function __flo_issues
    echo "Repository Issues"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Get project context
    set -l project_name (__flo_get_project_name)
    set -l base_root (test -n "$FLO_BASE_DIR"; and echo "$FLO_BASE_DIR"; or echo "$HOME/worktrees")
    set -l base_dir "$base_root/$project_name"

    # Get all worktrees for this project
    set -l worktree_branches
    if test -d "$base_dir"
        for worktree in "$base_dir"/*
            if test -d "$worktree"
                set -l name (basename $worktree)
                if string match -qr '^issue/(\d+)$' $name
                    set -l issue_num (string replace -r '^issue/(\d+)$' '$1' $name)
                    set worktree_branches $worktree_branches $issue_num
                end
            end
        end
    end

    # Get open issues
    set -l issues (gh issue list --json number,title,state,labels,assignees --limit 50)

    if test -z "$issues" -o "$issues" = "[]"
        set_color yellow
        echo "No open issues"
        set_color normal
        return 0
    end

    # Display issues with worktree status
    echo $issues | jq -r '.[] | [.number, .title, .state, (.labels | map(.name) | join(",")), (.assignees | map(.login) | join(","))] | @tsv' | while read -d \t number title state labels assignees
        echo -n "#$number: $title"

        # Check if has worktree
        if contains $number $worktree_branches
            set_color green
            echo -n " [✓ worktree]"
            set_color normal
        end

        # Show labels
        if test -n "$labels"
            set_color cyan
            echo -n " ($labels)"
            set_color normal
        end

        # Show assignees
        if test -n "$assignees"
            echo -n " @$assignees"
        end

        echo ""
    end

    echo ""

    # Summary
    set -l total_issues (echo $issues | jq 'length')
    set -l with_worktrees (count $worktree_branches)

    echo "Summary:"
    echo "  Total open issues: $total_issues"
    echo "  With worktrees: $with_worktrees"
    echo "  Without worktrees: "(math $total_issues - $with_worktrees)
end

function __flo_pr
    set -e argv[1]

    # Check for help flag
    if contains -- --help $argv; or test -z "$argv[1]"
        if test -z "$argv[1]"; or test "$argv[1]" = --help
            __flo_help_pr
            return 0
        end
    end

    # Default to status if no subcommand
    set -l subcmd $argv[1]
    if test -z "$subcmd"
        set subcmd status
    end
    set -e argv[1]

    switch $subcmd
        case create c
            __flo_pr_create $argv
        case open o
            __flo_pr_open $argv
        case status s
            __flo_pr_status $argv
        case list l
            __flo_pr_list $argv
        case help --help
            __flo_help_pr
            return 0
        case '*'
            set_color red
            echo "Unknown pr subcommand: $subcmd"
            set_color normal
            echo "Usage: flo pr [create|open|status|list]"
            echo "Run 'flo pr --help' for more information"
            return 1
    end
end

function __flo_pr_create
    # Get current branch
    set -l current_branch (git branch --show-current)
    if test -z "$current_branch"
        set_color red
        echo "Error: Not on a branch"
        set_color normal
        return 1
    end

    # Check if PR already exists
    set -l existing_pr (gh pr list --head $current_branch --json number --jq '.[0].number' 2>/dev/null)
    if test -n "$existing_pr"
        set_color yellow
        echo "PR #$existing_pr already exists for branch $current_branch"
        set_color normal
        gh pr view --web
        return 0
    end

    # Prepare PR title and body
    set -l pr_title ""
    set -l pr_body ""

    # Check if this is an issue branch
    if string match -qr '^issue/(\d+)$' $current_branch
        set -l issue_number (string replace -r '^issue/(\d+)$' '$1' $current_branch)

        # Get issue data
        set -l issue_data (gh issue view $issue_number --json title,body 2>/dev/null)
        if test -n "$issue_data"
            set -l issue_title (echo $issue_data | jq -r '.title')
            set pr_title "Fix: $issue_title"

            # Create PR body with Closes reference
            set pr_body "Closes #$issue_number

## Summary
This PR addresses issue #$issue_number: $issue_title

## Changes
- [ ] Implementation details here

## Test Plan
- [ ] Tests added/updated
- [ ] Manual testing completed"
        end
    end

    # Fall back to branch name if no issue
    if test -z "$pr_title"
        set pr_title (string replace -a '-' ' ' $current_branch | string replace -a '_' ' ')
        set pr_body "## Summary
Description here

## Changes
- [ ] Change 1

## Test Plan
- [ ] Tests added"
    end

    # Create PR
    echo "Creating pull request..."
    echo "Title: $pr_title"
    echo ""

    # Create PR with body via heredoc to handle multiline
    set -l pr_url (echo "$pr_body" | gh pr create --title "$pr_title" --body-file - --web 2>&1)

    if test $status -eq 0
        set_color green
        echo "Pull request created successfully"
        set_color normal
    else
        set_color red
        echo "Error creating pull request"
        set_color normal
        return 1
    end
end

function __flo_pr_open
    # Get current branch
    set -l current_branch (git branch --show-current)
    if test -z "$current_branch"
        set_color red
        echo "Error: Not on a branch"
        set_color normal
        return 1
    end

    # Check if PR exists
    set -l pr_number (gh pr list --head $current_branch --json number --jq '.[0].number' 2>/dev/null)
    if test -n "$pr_number"
        gh pr view --web
    else
        set_color yellow
        echo "No PR found for branch $current_branch"
        echo "Create one? [y/N]"
        set_color normal
        read -l reply
        if test "$reply" = y -o "$reply" = Y
            __flo_pr_create
        end
    end
end

function __flo_pr_status
    # Get current branch
    set -l current_branch (git branch --show-current)
    if test -z "$current_branch"
        # Not on a branch, show all PRs
        __flo_pr_list
        return
    end

    # Get PR for current branch
    set -l pr_data (gh pr list --head $current_branch --json number,title,state,url,reviewDecision,statusCheckRollup --jq '.[0]' 2>/dev/null)

    if test -z "$pr_data" -o "$pr_data" = null
        set_color yellow
        echo "No PR found for branch: $current_branch"
        set_color normal

        # Check if this is an issue branch
        if string match -qr '^issue/(\d+)$' $current_branch
            set -l issue_number (string replace -r '^issue/(\d+)$' '$1' $current_branch)
            echo ""
            echo "This is an issue branch for #$issue_number"
            echo "Run 'flo pr create' to create a PR"
        end
        return 0
    end

    # Parse PR data
    set -l pr_number (echo $pr_data | jq -r '.number')
    set -l pr_title (echo $pr_data | jq -r '.title')
    set -l pr_state (echo $pr_data | jq -r '.state')
    set -l pr_url (echo $pr_data | jq -r '.url')
    set -l review_decision (echo $pr_data | jq -r '.reviewDecision // "PENDING"')
    set -l checks (echo $pr_data | jq -r '.statusCheckRollup')

    # Display PR status
    set_color green
    echo "PR #$pr_number: $pr_title"
    set_color normal
    echo "State: $pr_state"
    echo "URL: $pr_url"

    # Review status
    echo -n "Reviews: "
    switch $review_decision
        case APPROVED
            set_color green
            echo "✓ Approved"
        case CHANGES_REQUESTED
            set_color red
            echo "✗ Changes requested"
        case REVIEW_REQUIRED
            set_color yellow
            echo "⏳ Review required"
        case '*'
            set_color yellow
            echo "⏳ Pending"
    end
    set_color normal

    # Check status
    if test "$checks" != null
        set -l checks_conclusion (echo $checks | jq -r '.conclusion // "IN_PROGRESS"')
        echo -n "Checks: "
        switch $checks_conclusion
            case SUCCESS
                set_color green
                echo "✓ All checks passed"
            case FAILURE
                set_color red
                echo "✗ Some checks failed"
            case '*'
                set_color yellow
                echo "⏳ In progress"
        end
        set_color normal
    end
end

function __flo_pr_list
    echo "Pull requests in current repository:"
    echo ""

    # Get all open PRs
    set -l prs (gh pr list --json number,title,author,branch,state --limit 20)

    if test -z "$prs" -o "$prs" = "[]"
        set_color yellow
        echo "No open pull requests"
        set_color normal
        return 0
    end

    # Display PRs
    echo $prs | jq -r '.[] | "#\(.number) \(.title) (\(.branch)) by @\(.author.login)"'
end

function __flo_sync --argument-names base_root
    echo "Syncing all worktrees..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if not test -d "$base_root"
        # Create base directory if it doesn't exist
        mkdir -p "$base_root"
        set_color yellow
        echo "No worktrees to sync"
        echo ""
        echo "Flo manages worktrees in: $base_root/<project>/<worktree-name>"
        echo "Use 'flo create <name>' to create your first worktree"
        set_color normal
        return 0
    end

    set -l updated_count 0
    set -l removed_count 0
    set -l error_count 0

    # Process each project
    for project_dir in "$base_root"/*
        if test -d "$project_dir"
            set -l project (basename $project_dir)

            set_color cyan
            echo "Project: $project"
            set_color normal

            # Process each worktree
            for worktree in "$project_dir"/*
                if test -d "$worktree"
                    set -l name (basename $worktree)
                    echo -n "  $name: "

                    # Check if it's a git worktree
                    if not test -f "$worktree/.git"
                        set_color red
                        echo "not a git worktree"
                        set_color normal
                        continue
                    end

                    # Get branch info
                    set -l branch (git -C "$worktree" branch --show-current 2>/dev/null)
                    if test -z "$branch"
                        set_color red
                        echo "no branch"
                        set_color normal
                        continue
                    end

                    # Check for merged PR
                    set -l pr_data (gh pr list --head $branch --state all --json number,state,mergedAt --jq '.[0]' 2>/dev/null)
                    if test -n "$pr_data" -a "$pr_data" != null
                        set -l pr_state (echo $pr_data | jq -r '.state')
                        set -l merged_at (echo $pr_data | jq -r '.mergedAt // empty')

                        if test "$pr_state" = MERGED -o -n "$merged_at"
                            set_color yellow
                            echo -n "PR merged - remove worktree? [y/N] "
                            set_color normal
                            read -l reply

                            if test "$reply" = y -o "$reply" = Y
                                git worktree remove "$worktree" 2>/dev/null; or git worktree remove --force "$worktree"
                                if test $status -eq 0
                                    set_color green
                                    echo "    ✓ Removed"
                                    set_color normal
                                    set removed_count (math $removed_count + 1)
                                else
                                    set_color red
                                    echo "    ✗ Failed to remove"
                                    set_color normal
                                    set error_count (math $error_count + 1)
                                end
                                continue
                            else
                                echo -n "    Kept, "
                            end
                        end
                    end

                    # Update from upstream
                    cd "$worktree"
                    set -l upstream (git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
                    if test -n "$upstream"
                        git fetch origin 2>/dev/null
                        set -l behind (git rev-list --count HEAD...$upstream 2>/dev/null)
                        if test -n "$behind" -a $behind -gt 0
                            echo -n "pulling $behind commits... "
                            git pull --rebase 2>&1 >/dev/null
                            if test $status -eq 0
                                set_color green
                                echo "✓"
                                set_color normal
                                set updated_count (math $updated_count + 1)
                            else
                                set_color red
                                echo "✗ conflicts"
                                set_color normal
                                set error_count (math $error_count + 1)
                            end
                        else
                            echo "up to date"
                        end
                    else
                        echo "no upstream"
                    end

                    # Update cache for issue worktrees
                    if string match -qr '^issue/(\d+)$' $name
                        set -l issue_number (string replace -r '^issue/(\d+)$' '$1' $name)
                        echo -n "    Updating issue cache... "

                        # Get fresh issue data
                        set -l issue_data (gh issue view $issue_number --json number,title,state,body,labels,assignees 2>/dev/null)
                        if test -n "$issue_data"
                            __flo_create_issue_context $worktree $issue_number $issue_data >/dev/null 2>&1
                            set_color green
                            echo "✓"
                            set_color normal
                        else
                            set_color red
                            echo "✗"
                            set_color normal
                        end
                    end
                end
            end
            echo ""
        end
    end

    # Summary
    set_color cyan
    echo "Summary:"
    set_color normal
    echo "  Updated: $updated_count worktrees"
    echo "  Removed: $removed_count worktrees"
    if test $error_count -gt 0
        set_color red
        echo "  Errors: $error_count"
        set_color normal
    end
end

function __flo_zed --argument-names base_root in_git_repo project_name
    set -e argv[1..3]

    # If no argument, open current directory
    if test (count $argv) -eq 0
        zed .
        return
    end

    set -l target $argv[1]
    set -l worktree_path ""

    # Determine worktree path
    if string match -q '*/*' $target
        # Project/name format
        set worktree_path "$base_root/$target"
    else if test $in_git_repo = true -a -n "$project_name"
        # In git repo, use current project
        set worktree_path "$base_root/$project_name/$target"
    else
        set_color red
        echo "Error: Not in a git repository. Use 'flo zed <project>/<name>' format"
        set_color normal
        return 1
    end

    if not test -d "$worktree_path"
        set_color red
        echo "Error: Worktree '$target' does not exist"
        set_color normal
        return 1
    end

    # Open in Zed
    zed "$worktree_path"
    set_color green
    echo "Opened $target in Zed"
    set_color normal
end

function __flo_validate_name --argument-names name
    # Check for empty name
    if test -z "$name"
        set_color red
        echo "Error: Worktree name cannot be empty"
        set_color normal
        return 1
    end

    # Check for invalid characters
    if string match -q -r '[\\:*?"<>|]' $name
        set_color red
        echo "Error: Invalid characters in worktree name: $name"
        echo "Avoid: \\ : * ? \" < > |"
        set_color normal
        return 1
    end

    # Allow forward slash for project/name format
    # Warn about spaces (but allow them)
    if string match -q '* *' $name
        set_color yellow
        echo "Warning: Worktree name contains spaces: '$name'"
        set_color normal
    end

    return 0
end
