# Flo - Git workflow automation tool
# Main entry point and CLI dispatcher

set -l flo_dir (dirname (status -f))

# Source the CLI framework and internals
source "$flo_dir/../lib/cli/\$.fish"
source "$flo_dir/../lib/internals.fish"

# Initialize flo with the CLI framework
__cli_init \
    --name flo \
    --prefix flo \
    --dir $flo_dir \
    --version "2.0.0"

# Register command dependencies
__cli_register_deps start git gh
__cli_register_deps end git
__cli_register_deps list git
__cli_register_deps prune git

# Helper to indent output lines (for git/gh commands)
function __flo_indent
    while read -l line
        echo "    $line"
    end
end

# Helper to generate branch slug from issue title
function __flo_slugify_title --description "Convert issue title to branch slug"
    set -l title $argv[1]
    # Slugify: lowercase, replace non-alphanumeric with hyphens, limit to 30 chars
    echo $title | string lower | string replace -ra '[^a-z0-9]+' - | string trim -c - | string sub -l 30 | string trim -c -
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
    set -l green $argv[2]
    set -l yellow $argv[3]
    set -l reset $argv[4]
    set -l blue $argv[5]

    echo "  $blue•$reset Assigning issue to you..."
    set -l output (gh issue edit $issue_number --add-assignee @me 2>&1)
    set -l exit_code $status
    echo "$output" | __flo_indent
    if test $exit_code -eq 0
        echo "  $green✓$reset Issue assigned"
    else
        echo "  $yellow⚠$reset Could not auto-assign (continuing anyway)"
    end
end

# Success message helper
function __flo_print_success_message --description "Print success message with issue details if applicable"
    set -l is_issue $argv[1]
    set -l issue_number $argv[2]
    set -l green $argv[3]
    set -l reset $argv[4]
    set -l dim $argv[5]
    set -l cyan $argv[6]

    echo "" >&2
    echo "  $green✓ Ready to work!$reset" >&2
    if test "$is_issue" = true
        echo "  $dim•$reset Issue $cyan#$issue_number$reset assigned to you" >&2
        echo "  $dim•$reset Issue context available in $cyan.claude/CLAUDE.local.md$reset" >&2
        echo "  $dim•$reset Tip: Claude will read this context automatically" >&2
    end
end

# Dependency installation helper
function __flo_install_dependencies --description "Install npm dependencies if package.json exists"
    set -l worktree_path $argv[1]
    set -l blue $argv[2]
    set -l green $argv[3]
    set -l yellow $argv[4]
    set -l reset $argv[5]

    if test -f "$worktree_path/package.json"
        echo "  $blue•$reset Installing dependencies..." >&2
        cd $worktree_path
        pnpm install --silent
        if test $status -eq 0
            echo "  $green✓$reset Dependencies installed" >&2
        else
            echo "  $yellow⚠$reset pnpm install failed (continuing anyway)" >&2
        end
    else
        # No package.json, just cd into worktree
        cd $worktree_path
    end
end

# Claude context helpers
function __flo_setup_claude_md --description "Setup or detect CLAUDE.md in worktree"
    set -l worktree_path $argv[1]
    set -l blue $argv[2]
    set -l cyan $argv[3]
    set -l green $argv[4]
    set -l dim $argv[5]
    set -l reset $argv[6]

    # Check if root CLAUDE.md exists first - if so, skip creating .claude/CLAUDE.md
    if test -f "$worktree_path/CLAUDE.md"
        echo "  $blue•$reset Using existing $cyan./CLAUDE.md$reset" >&2
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
            echo "  $green✓$reset Created $cyan.claude/CLAUDE.md$reset $dim(local extension support)$reset" >&2
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
            echo "  $green✓$reset Added local extension support to $cyan.claude/CLAUDE.md$reset" >&2
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
    set -l green $argv[10]
    set -l cyan $argv[11]
    set -l dim $argv[12]
    set -l reset $argv[13]

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

    echo "  $green✓$reset Created $cyan.claude/CLAUDE.local.md$reset $dim(issue context)$reset" >&2
end

function __flo_setup_gitignore --description "Add .claude/*.local.md to .gitignore"
    set -l worktree_path $argv[1]
    set -l green $argv[2]
    set -l cyan $argv[3]
    set -l reset $argv[4]

    if test -f "$worktree_path/.gitignore"
        if not grep -Fxq '.claude/*.local.md' "$worktree_path/.gitignore"
            echo ".claude/*.local.md" >>"$worktree_path/.gitignore"
            echo "  $green✓$reset Added $cyan.claude/*.local.md$reset to .gitignore" >&2
        end
    end
end

# Worktree management helpers
function __flo_create_or_use_worktree --description "Create worktree or detect existing"
    set -l worktree_path $argv[1]
    set -l branch_name $argv[2]
    set -l blue $argv[3]
    set -l cyan $argv[4]
    set -l red $argv[5]
    set -l reset $argv[6]

    # Check if worktree already exists
    if test -d $worktree_path
        echo "  $blue•$reset Worktree already exists: $cyan$worktree_path$reset" >&2
        echo existed
        return 0
    end

    # Create the worktree (try existing branch first, create new if needed)
    set -l output (git worktree add $worktree_path $branch_name 2>&1)
    set -l exit_code $status
    echo "$output" | __flo_indent >&2

    if test $exit_code -ne 0
        # Branch doesn't exist, create it
        set output (git worktree add -b $branch_name $worktree_path 2>&1)
        set exit_code $status
        echo "$output" | __flo_indent >&2

        if test $exit_code -ne 0
            echo "  $red✗ Error:$reset Could not create worktree" >&2
            return 1
        end
    end

    echo created
    return 0
end

function __flo_copy_serena_cache --description "Copy Serena cache to worktree if exists"
    set -l worktree_path $argv[1]
    set -l blue $argv[2]
    set -l green $argv[3]
    set -l yellow $argv[4]
    set -l dim $argv[5]
    set -l reset $argv[6]

    if test -d .serena/cache
        echo "  $blue•$reset Copying Serena cache..." >&2
        mkdir -p "$worktree_path/.serena"
        cp -r .serena/cache "$worktree_path/.serena/cache"
        if test $status -eq 0
            echo "  $green✓$reset Serena cache copied $dim(speeds up symbol indexing)$reset" >&2
        else
            echo "  $yellow⚠$reset Could not copy Serena cache (continuing anyway)" >&2
        end
    end
end

# Main command - create worktree from branch name or GitHub issue number
function flo_start
    # Colors for output
    set -l blue (set_color brblue)
    set -l green (set_color brgreen)
    set -l yellow (set_color bryellow)
    set -l red (set_color brred)
    set -l cyan (set_color brcyan)
    set -l dim (set_color brblack)
    set -l reset (set_color normal)

    # Print newline after command name
    echo ""

    set current_dir (basename (pwd))
    set arg $argv[1]

    # Strip leading # if present (e.g., #123 -> 123)
    set arg (string replace -r '^#' '' -- $arg)

    # Check if argument is an issue number (integer)
    if string match -qr '^\d+$' -- $arg
        # --- Issue Mode: Fetch from GitHub ---

        # Validate gh CLI is installed
        if not command -v gh >/dev/null 2>&1
            echo "  $red✗ Error:$reset gh CLI not installed"
            echo "    Install with: brew install gh"
            echo "    Or visit: https://cli.github.com"
            return 1
        end

        echo "  $blue•$reset Fetching issue $cyan#$arg$reset..."

        # Fetch issue data as JSON using gh CLI (including comments)
        set issue_json (__flo_fetch_issue $arg)

        if test $status -ne 0
            echo "  $red✗ Error:$reset Could not fetch issue $cyan#$arg$reset"
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

        echo "  $blue•$reset Creating branch: $cyan$branch_name$reset"

        # Auto-assign issue to current GitHub user
        __flo_assign_issue $arg $green $yellow $reset $blue

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
    set worktree_status (__flo_create_or_use_worktree $worktree_path $branch_name $blue $cyan $red $reset)
    if test $status -ne 0
        return 1
    end

    # Copy Serena cache (only for new worktrees)
    if test "$worktree_status" = created
        __flo_copy_serena_cache $worktree_path $blue $green $yellow $dim $reset
    end
    set worktree_existed (test "$worktree_status" = existed; and echo true; or echo false)

    # If created from issue, store issue metadata and generate Claude context
    if test "$is_issue" = true
        # Store issue number in global tracking file
        set -l full_path (realpath $worktree_path)
        __flo_internal_config_set "$full_path" "$issue_number" "$branch_name"

        echo "  $blue•$reset Creating Claude context..."
        mkdir -p "$worktree_path/.claude"

        # Setup CLAUDE.md and generate CLAUDE.local.md
        __flo_setup_claude_md "$worktree_path" "$blue" "$cyan" "$green" "$dim" "$reset"
        __flo_generate_claude_local "$worktree_path" "$issue_number" "$issue_title" "$issue_url" "$issue_labels" "$branch_name" "$issue_body" "$issue_comments_count" "$issue_comments_formatted" "$green" "$cyan" "$dim" "$reset"
        __flo_setup_gitignore "$worktree_path" "$green" "$cyan" "$reset"
    end

    # Auto-install npm dependencies if package.json exists (skip if worktree existed)
    if not set -q worktree_existed; or test "$worktree_existed" = false
        __flo_install_dependencies "$worktree_path" "$blue" "$green" "$yellow" "$reset"
    else
        # Worktree existed, just cd into it
        cd $worktree_path
    end

    # Success message
    __flo_print_success_message "$is_issue" "$issue_number" "$green" "$reset" "$dim" "$cyan"
end
