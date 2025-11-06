# Flo - Git workflow automation tool
# Main entry point and CLI dispatcher

# Get the directory where this file lives (same as other lib files in Fisher setup)
set -l flo_dir (dirname (status --current-filename))

# Source the CLI framework and internals
source "$flo_dir/__flo_lib_cli_main.fish"
source "$flo_dir/__flo_lib_internals.fish"
source "$flo_dir/__flo_lib_log.fish"

# Initialize flo with the CLI framework
__cli_init \
    --name flo \
    --prefix flo \
    --dir $flo_dir \
    --version "2.0.0"

# Register command dependencies
__cli_register_deps start git gh
__cli_register_deps end git gh
__cli_register_deps list git
__cli_register_deps prune git

# Global color variables (used by all helper functions)
set -g __flo_c_blue (set_color brblue)
set -g __flo_c_green (set_color brgreen)
set -g __flo_c_yellow (set_color bryellow)
set -g __flo_c_red (set_color brred)
set -g __flo_c_cyan (set_color brcyan)
set -g __flo_c_dim (set_color brblack)
set -g __flo_c_reset (set_color normal)

# Helper to indent output lines (for git/gh commands)
function __flo_indent
    while read -l line
        echo "    $line"
    end
end

function __flo_require_gh --description "Check if gh CLI is installed, error if not"
    if not command -v gh >/dev/null 2>&1
        __flo_log_error "gh CLI not installed" "Install with: brew install gh or visit https://cli.github.com"
        return 1
    end
    return 0
end

# Helper to generate branch slug from issue title
function __flo_slugify_title --description "Convert issue title to branch slug"
    set -l title $argv[1]
    # Slugify: lowercase, replace non-alphanumeric with hyphens, limit to 30 chars
    echo $title | string lower | string replace -ra '[^a-z0-9]+' - | string trim -c - | string sub -l 30 | string trim -c -
end

# Settings management
function __flo_ensure_settings --description "Create settings file if missing, return path"
    set -l settings_dir "$HOME/.config/flo"
    set -l settings_file "$settings_dir/settings.json"

    if not test -f "$settings_file"
        mkdir -p "$settings_dir"
        echo '{}' >"$settings_file"
    end

    echo "$settings_file"
end

function __flo_get_projects_directories --description "Get project directory patterns from settings"
    set -l settings_file (__flo_ensure_settings)

    # Parse projectsDirectories array
    jq -r '.projectsDirectories[]?' "$settings_file" 2>/dev/null
end

function __flo_resolve_project_name --description "Resolve project name to path using settings"
    set -l input $argv[1]

    # Get configured patterns
    set -l patterns (__flo_get_projects_directories)

    if test -z "$patterns"
        # No settings - cannot resolve names
        return 1
    end

    set -l matches

    # Expand each pattern and search for fuzzy match
    for pattern in $patterns
        # Expand glob (tilde and wildcards) into array
        eval "set -l expanded $pattern"

        for dir in $expanded
            if not test -d "$dir"
                continue
            end

            set -l basename (basename "$dir")

            # Fuzzy match: input is case-insensitive substring of basename
            if string match -qi "*$input*" -- "$basename"
                set -a matches (realpath "$dir")
            end
        end
    end

    # Handle results
    set -l match_count (count $matches)

    if test $match_count -eq 0
        # No matches found
        return 2
    else if test $match_count -eq 1
        # Single match - success!
        echo $matches[1]
        return 0
    else
        # Multiple matches - try interactive picker if available
        if command -v gum >/dev/null 2>&1; and test -t 0
            # Interactive session with gum - show picker
            set -l selected (printf '%s\n' $matches | gum choose --header "Multiple projects match '$input':")
            if test -n "$selected"
                echo "$selected"
                return 0
            else
                # User cancelled picker
                return 4
            end
        else
            # Non-interactive or no gum - ambiguous error
            printf '%s\n' $matches >&2
            return 3
        end
    end
end

function __flo_resolve_project_path --description "Resolve --project argument to absolute path"
    set -l input $argv[1]

    # Check if input is a path (absolute or explicit relative)
    if string match -q '/*' -- $input
        # Absolute path - use as-is
        if test -d "$input"
            realpath "$input"
            return 0
        else
            echo "✗ Directory not found: $input" >&2
            return 1
        end
    else if string match -qr '^\.\.?/' -- $input
        # Explicit relative path (./ or ../)
        set -l resolved (realpath "$input" 2>/dev/null)
        if test -n "$resolved"; and test -d "$resolved"
            echo "$resolved"
            return 0
        else
            echo "✗ Directory not found: $input" >&2
            return 1
        end
    else
        # Bare name - try name resolution
        set -l resolved (__flo_resolve_project_name "$input" 2>/dev/null)
        set -l status_code $status

        if test $status_code -eq 0
            # Single match found
            echo "$resolved"
            return 0
        else if test $status_code -eq 1
            # No settings configured
            echo "✗ Project name '$input' cannot be resolved" >&2
            echo "" >&2
            echo "To use project names, configure ~/.config/flo/settings.json:" >&2
            echo '{' >&2
            echo '  "projectsDirectories": ["~/projects/*/*"]' >&2
            echo '}' >&2
            echo "" >&2
            echo "Or use explicit path (use ./ for relative):" >&2
            echo "  --project ~/projects/$input" >&2
            echo "  --project ./$input" >&2
            return 1
        else if test $status_code -eq 2
            # No matches found
            set -l patterns (__flo_get_projects_directories)
            echo "✗ Project '$input' not found" >&2
            echo "" >&2
            echo "Searched in:" >&2
            for pattern in $patterns
                echo "  $pattern" >&2
            end
            echo "" >&2
            echo "Use explicit path:" >&2
            echo "  --project ~/other/location/$input" >&2
            return 1
        else if test $status_code -eq 3
            # Multiple matches (non-interactive or no gum)
            set -l matched_paths (__flo_resolve_project_name "$input" 2>&1 >/dev/null)
            echo "✗ Ambiguous project name '$input' matches multiple:" >&2
            echo "" >&2
            set -l i 1
            for path in $matched_paths
                echo "  $i. $path" >&2
                set i (math $i + 1)
            end
            echo "" >&2
            echo "Use explicit path:" >&2
            echo "  --project $matched_paths[1]" >&2
            return 1
        else if test $status_code -eq 4
            # User cancelled interactive picker
            echo Cancelled >&2
            return 1
        end
    end
end

# Interactive issue selection with gum
function __flo_select_issue --description "Interactively select an issue with gum"
    # Check if gum is installed
    if not command -v gum >/dev/null 2>&1
        return 1
    end

    # Check if gh is installed
    if not command -v gh >/dev/null 2>&1
        return 1
    end

    # Fetch and format open issues using gh template
    set -l formatted_issues (gh issue list --state open --limit 100 --json number,title --template '{{range .}}#{{.number}} - {{.title}}{{"\n"}}{{end}}' 2>/dev/null)
    if test $status -ne 0; or test -z "$formatted_issues"
        return 1
    end

    # Count issues by counting lines (use printf to handle array properly)
    set -l issue_count (printf '%s\n' $formatted_issues | wc -l | string trim)
    if test "$issue_count" -eq 0
        return 1
    end

    # Use gum filter for >10 issues, choose for <=10
    set -l selected
    if test "$issue_count" -gt 10
        set selected (printf '%s\n' $formatted_issues | gum filter --placeholder "Search issues..." --height 15)
    else
        set selected (printf '%s\n' $formatted_issues | gum choose --header "Select an issue:")
    end

    # Extract issue number from selection (format: #123 - Title)
    if test -n "$selected"
        echo "$selected" | string replace -r '^#(\d+).*' '$1'
        return 0
    else
        return 1
    end
end

# Issue handling helpers
function __flo_fetch_issue --description "Fetch GitHub issue as JSON"
    set -l issue_number $argv[1]
    gh issue view $issue_number --json number,title,body,labels,url,comments 2>/dev/null
end

function __flo_get_issue_field --description "Extract field from issue JSON"
    set -l issue_json $argv[1]
    set -l field $argv[2]
    set -l default_value $argv[3]

    if test -n "$default_value"
        echo $issue_json | jq -r ".$field // \"$default_value\""
    else
        echo $issue_json | jq -r ".$field"
    end
end

function __flo_get_issue_labels --description "Get comma-separated labels from issue JSON"
    set -l issue_json $argv[1]
    echo $issue_json | jq -r '.labels[].name' | string join ', '
end

function __flo_get_comments_count --description "Get comment count from issue JSON"
    set -l issue_json $argv[1]
    echo $issue_json | jq -r '.comments | length'
end

function __flo_format_comments --description "Format issue comments for output"
    set -l issue_json $argv[1]
    echo $issue_json | jq -r '.comments[] | "### Comment by @\(.author.login) (\\(.createdAt))\n\n\(.body)\n"'
end

# Branch management helpers
function __flo_determine_branch_prefix --description "Determine branch prefix from issue labels"
    set -l issue_labels $argv[1]

    if string match -qir '(bug|fix)' -- $issue_labels
        echo fix
    else if string match -qir '(docs|documentation)' -- $issue_labels
        echo docs
    else if string match -qir refactor -- $issue_labels
        echo refactor
    else if string match -qir chore -- $issue_labels
        echo chore
    else
        echo feat # Default to feature
    end
end

function __flo_create_branch_name --description "Build branch name from components"
    set -l branch_prefix $argv[1]
    set -l issue_number $argv[2]
    set -l issue_title $argv[3]

    set -l title_slug (__flo_slugify_title $issue_title)
    echo "$branch_prefix/$issue_number-$title_slug"
end

function __flo_assign_issue --description "Auto-assign issue to current user"
    set -l issue_number $argv[1]

    __flo_log_info "Assigning issue to you..."
    set -l output (gh issue edit $issue_number --add-assignee @me 2>&1)
    set -l exit_code $status
    echo "$output" | __flo_indent
    if test $exit_code -eq 0
        __flo_log_success "Issue assigned"
    else
        __flo_log_warn "Could not auto-assign (continuing anyway)"
    end
end

# Success message helper
function __flo_print_success_message --description "Print success message with issue details if applicable"
    set -l is_issue $argv[1]
    set -l issue_number $argv[2]

    echo ""
    echo ""
    __flo_log_success "Ready to work!"
    if test "$is_issue" = true
        __flo_log_info_dim "Issue $__flo_c_cyan#$issue_number$__flo_c_reset assigned to you"
        __flo_log_info_dim "Issue context available in $__flo_c_cyan.claude/CLAUDE.local.md$__flo_c_reset"
        __flo_log_info_dim "Tip: Claude will read this context automatically"
    end
end

# Dependency installation helper
function __flo_install_dependencies --description "Install npm dependencies if package.json exists"
    set -l worktree_path $argv[1]

    if test -f "$worktree_path/package.json"
        __flo_log_info "Installing dependencies..."
        cd $worktree_path
        pnpm install --silent
        if test $status -eq 0
            __flo_log_success "Dependencies installed"
        else
            __flo_log_warn "pnpm install failed (continuing anyway)"
        end
    else
        # No package.json, just cd into worktree
        cd $worktree_path
    end
end

# Claude context helpers
function __flo_setup_claude_md --description "Setup or detect CLAUDE.md in worktree"
    set -l worktree_path $argv[1]

    # Check if root CLAUDE.md exists first - if so, skip creating .claude/CLAUDE.md
    if test -f "$worktree_path/CLAUDE.md"
        __flo_log_info "Using existing $__flo_c_cyan./CLAUDE.md$__flo_c_reset"
    else
        # Root CLAUDE.md doesn't exist - create .claude/CLAUDE.md with extension marker
        set -l claude_md "$worktree_path/.claude/CLAUDE.md"
        set -l extension_marker "<!-- flo: local extension enabled -->"

        if not test -f "$claude_md"
            # Create CLAUDE.md with extension instruction
            printf '%s\n' \
                '<!-- flo: local extension enabled -->' \
                '' \
                '**CRITICAL**: If a file named `.claude/CLAUDE.local.md` exists in this project, read it immediately and follow its instructions. This file contains context-specific information for the current work (e.g., GitHub issue details).' >"$claude_md"
            __flo_log_success "Created $__flo_c_cyan.claude/CLAUDE.md$__flo_c_reset $__flo_c_dim(local extension support)$__flo_c_reset"
        else if not grep -q "$extension_marker" "$claude_md"
            # CLAUDE.md exists but doesn't have the extension instruction - prepend it
            set -l temp_file (mktemp)
            printf '%s\n' \
                '<!-- flo: local extension enabled -->' \
                '' \
                '**CRITICAL**: If a file named `.claude/CLAUDE.local.md` exists in this project, read it immediately and follow its instructions. This file contains context-specific information for the current work (e.g., GitHub issue details).' \
                '' \
                --- \
                '' >"$temp_file"
            cat "$claude_md" >>"$temp_file"
            mv "$temp_file" "$claude_md"
            __flo_log_success "Added local extension support to $__flo_c_cyan.claude/CLAUDE.md$__flo_c_reset"
        end
    end
end

function __flo_generate_claude_local --description "Generate CLAUDE.local.md with issue context"
    set -l worktree_path $argv[1]
    set -l issue_number $argv[2]
    set -l issue_title $argv[3]
    set -l issue_url $argv[4]
    set -l issue_labels $argv[5]
    set -l branch_name $argv[6]
    set -l issue_body $argv[7]
    set -l issue_comments_count $argv[8]
    set -l issue_comments_formatted $argv[9]

    # Write issue details to .claude/CLAUDE.local.md for Claude Code to read
    printf '%s\n' \
        '# GitHub Issue Context' \
        '' \
        '**CRITICAL: Read this ENTIRE issue including ALL comments below. Later comments take precedence over earlier ones.**' \
        '' \
        "## Issue #$issue_number: $issue_title" \
        '' \
        "- **URL**: $issue_url" \
        "- **Labels**: $issue_labels" \
        "- **Branch**: \`$branch_name\`" \
        '' \
        '## Original Description' \
        '' \
        "$issue_body" \
        '' >"$worktree_path/.claude/CLAUDE.local.md"

    # Append comments if any exist
    if test $issue_comments_count -gt 0
        printf '%s\n' \
            '## Comments' \
            '' \
            '**Note: Read ALL comments below. If there are contradictions between the original description and comments, or between earlier and later comments, follow the most recent information.**' \
            '' >>"$worktree_path/.claude/CLAUDE.local.md"

        # Append each comment
        echo "$issue_comments_formatted" >>"$worktree_path/.claude/CLAUDE.local.md"

        printf '%s\n' \
            '' \
            --- \
            '' >>"$worktree_path/.claude/CLAUDE.local.md"
    else
        printf '%s\n' \
            --- \
            '' >>"$worktree_path/.claude/CLAUDE.local.md"
    end

    # Append instructions
    printf '%s\n' \
        '## Instructions for Claude' \
        '' \
        '1. Read and fully understand the issue requirements above **and all comments**' \
        '2. If there are comments, they may clarify, modify, or override the original description - follow the latest information' \
        '3. All changes in this worktree should directly address this issue' \
        "4. Reference this issue number (#$issue_number) in commit messages" \
        '5. Consider the labels when determining the scope of changes' \
        "6. When done, ensure the PR description references this issue with \"Closes #$issue_number\"" \
        '' >>"$worktree_path/.claude/CLAUDE.local.md"

    __flo_log_success "Created $__flo_c_cyan.claude/CLAUDE.local.md$__flo_c_reset $__flo_c_dim(issue context)$__flo_c_reset"
end

function __flo_setup_gitignore --description "Add .claude/*.local.md to .gitignore"
    set -l worktree_path $argv[1]

    if test -f "$worktree_path/.gitignore"
        if not grep -Fxq '.claude/*.local.md' "$worktree_path/.gitignore"
            echo ".claude/*.local.md" >>"$worktree_path/.gitignore"
            __flo_log_success "Added $__flo_c_cyan.claude/*.local.md$__flo_c_reset to .gitignore"
        end
    end
end

# Worktree management helpers
function __flo_create_or_use_worktree --description "Create worktree or detect existing"
    set -l worktree_path $argv[1]
    set -l branch_name $argv[2]

    # Check if worktree already exists
    if test -d $worktree_path
        __flo_log_info "Worktree already exists: $__flo_c_cyan$worktree_path$__flo_c_reset"
        echo existed
        return 0
    end

    # Create the worktree (try existing branch first, create new if needed)
    # Suppress error from first attempt - it's expected to fail when branch doesn't exist
    set -l output (git worktree add $worktree_path $branch_name 2>/dev/null)
    set -l exit_code $status

    if test $exit_code -ne 0
        # Branch doesn't exist, create it
        set output (git worktree add -b $branch_name $worktree_path 2>&1)
        set exit_code $status
        echo "$output" | __flo_indent >&2

        if test $exit_code -ne 0
            __flo_log_error "Could not create worktree"
            return 1
        end
    else
        # Existing branch checkout succeeded - show output
        echo "$output" | __flo_indent >&2
    end

    echo created
    return 0
end

function __flo_copy_serena_cache --description "Copy Serena cache to worktree if exists"
    set -l worktree_path $argv[1]

    if test -d .serena/cache
        __flo_log_info "Copying Serena cache..."
        mkdir -p "$worktree_path/.serena"
        cp -r .serena/cache "$worktree_path/.serena/cache"
        if test $status -eq 0
            __flo_log_success "Serena cache copied $__flo_c_dim(speeds up symbol indexing)$__flo_c_reset"
        else
            __flo_log_warn "Could not copy Serena cache (continuing anyway)"
        end
    end
end

# Main command - create worktree from branch name or GitHub issue number
function flo_start
    # Parse flags
    argparse 'project=' claude -- $argv; or return

    # Resolve project path if --project provided
    set -l project_path (pwd)
    if set -q _flag_project
        set project_path (__flo_resolve_project_path "$_flag_project")
        if test $status -ne 0
            # Error already printed by resolver
            return 1
        end
        cd "$project_path" || return 1
    end

    # If we're in a flo worktree, cd to the main worktree first
    # Flo worktrees have pattern: <project>_<branch-with-dashes>
    set -l current_path (realpath (pwd))
    set -l current_basename (basename $current_path)

    if string match -qr _ -- $current_basename
        # Looks like a flo worktree - verify with git and get main worktree
        set -l main_worktree (git worktree list --porcelain 2>/dev/null | grep "^worktree" | head -1 | string replace "worktree " "")

        if test -n "$main_worktree"; and test -d "$main_worktree"
            # We're in a git worktree and found the main worktree
            if test "$current_path" != "$main_worktree"
                # We're not in the main worktree, cd to it
                echo ""
                __flo_log_info "Detected flo worktree, switching to main project..."
                cd "$main_worktree" || return 1
                set project_path "$main_worktree"
            end
        end
    end

    # Print newline after command name (skip if already printed above)
    if test "$current_path" = "$project_path"
        echo ""
    end

    set current_dir (basename $project_path)
    set arg $argv[1]

    # Strip leading # if present (e.g., #123 -> 123)
    set arg (string replace -r '^#' '' -- $arg)

    # Check if argument is an issue number (integer)
    if string match -qr '^\d+$' -- $arg
        # --- Issue Mode: Fetch from GitHub ---

        # Validate gh CLI is installed
        __flo_require_gh; or return

        __flo_log_info "Fetching issue $__flo_c_cyan#$arg$__flo_c_reset..."

        # Fetch issue data as JSON using gh CLI (including comments)
        set issue_json (__flo_fetch_issue $arg)

        if test $status -ne 0
            __flo_log_error "Could not fetch issue $__flo_c_cyan#$arg$__flo_c_reset"
            return 1
        end

        # Parse JSON fields
        set issue_number (__flo_get_issue_field $issue_json number)
        set issue_title (__flo_get_issue_field $issue_json title)
        set issue_body (__flo_get_issue_field $issue_json body "No description provided")
        set issue_url (__flo_get_issue_field $issue_json url)
        set issue_labels (__flo_get_issue_labels $issue_json)

        # Parse comments
        set issue_comments_count (__flo_get_comments_count $issue_json)
        set issue_comments_formatted ""
        if test $issue_comments_count -gt 0
            set issue_comments_formatted (__flo_format_comments $issue_json)
        end

        # Determine branch prefix and create branch name
        set branch_prefix (__flo_determine_branch_prefix $issue_labels)
        set branch_name (__flo_create_branch_name $branch_prefix $issue_number $issue_title)

        __flo_log_info "Creating branch: $__flo_c_cyan$branch_name$__flo_c_reset"

        # Auto-assign issue to current GitHub user
        __flo_assign_issue $arg

        set is_issue true

    else
        # --- Branch Mode: Use provided branch name directly ---
        set branch_name $arg
        set is_issue false
    end

    # Create worktree directory path: ../<current-dir>_<sanitized-branch-name>
    set sanitized_branch (string replace -a '/' '-' $branch_name)
    set worktree_path "../$current_dir"_"$sanitized_branch"

    # Create worktree or detect existing
    set worktree_status (__flo_create_or_use_worktree $worktree_path $branch_name)
    if test $status -ne 0
        return 1
    end

    # Copy Serena cache (only for new worktrees)
    if test "$worktree_status" = created
        __flo_copy_serena_cache $worktree_path
    end
    set worktree_existed (test "$worktree_status" = existed; and echo true; or echo false)

    # If created from issue, store issue metadata and generate Claude context
    if test "$is_issue" = true
        # Store issue number in global tracking file
        set -l full_path (realpath $worktree_path)
        __flo_internal_config_set "$full_path" "$issue_number" "$branch_name"

        __flo_log_info "Creating Claude context..."
        mkdir -p "$worktree_path/.claude"

        # Setup CLAUDE.md and generate CLAUDE.local.md
        __flo_setup_claude_md "$worktree_path"
        __flo_generate_claude_local "$worktree_path" "$issue_number" "$issue_title" "$issue_url" "$issue_labels" "$branch_name" "$issue_body" "$issue_comments_count" "$issue_comments_formatted"
        __flo_setup_gitignore "$worktree_path"
    end

    # Auto-install npm dependencies if package.json exists (skip if worktree existed)
    if not set -q worktree_existed; or test "$worktree_existed" = false
        __flo_install_dependencies "$worktree_path"
    else
        # Worktree existed, just cd into it
        cd $worktree_path
    end

    # Success message
    __flo_print_success_message "$is_issue" "$issue_number"

    # Open Zed at worktree directory
    zed $worktree_path

    # Optionally launch Claude in current terminal
    if set -q _flag_claude
        claude /start
    end
end
