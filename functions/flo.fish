# Flo - Git workflow automation tool
# Main entry point and CLI dispatcher

set -l flo_dir (dirname (status -f))

# Source the CLI framework
source "$flo_dir/../lib/cli/\$.fish"

# Initialize flo with the CLI framework
__cli_init \
    --name flo \
    --prefix flo \
    --dir $flo_dir \
    --version "2.0.0"

# Register command dependencies
__cli_register_deps list git
__cli_register_deps rm git
__cli_register_deps prune git

# Helper to indent output lines (for git/gh commands)
function __flo_indent
    while read -l line
        echo "    $line"
    end
end

# Main command - create worktree from branch name or GitHub issue number
function flo_flo
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
        set issue_json (gh issue view $arg --json number,title,body,labels,url,comments 2>/dev/null)

        if test $status -ne 0
            echo "  $red✗ Error:$reset Could not fetch issue $cyan#$arg$reset"
            return 1
        end

        # Parse JSON fields using jq
        set issue_number (echo $issue_json | jq -r '.number')
        set issue_title (echo $issue_json | jq -r '.title')
        set issue_body (echo $issue_json | jq -r '.body // "No description provided"')
        set issue_url (echo $issue_json | jq -r '.url')
        set issue_labels (echo $issue_json | jq -r '.labels[].name' | string join ', ')

        # Parse comments (author + body for each comment)
        set issue_comments_count (echo $issue_json | jq -r '.comments | length')
        set issue_comments_formatted ""
        if test $issue_comments_count -gt 0
            # Format all comments with author and body
            set issue_comments_formatted (echo $issue_json | jq -r '.comments[] | "### Comment by @\(.author.login) (\\(.createdAt))\n\n\(.body)\n"')
        end

        # Determine branch prefix based on issue labels
        set branch_prefix feat # Default to feature
        if string match -qir '(bug|fix)' -- $issue_labels
            set branch_prefix fix
        else if string match -qir '(docs|documentation)' -- $issue_labels
            set branch_prefix docs
        else if string match -qir refactor -- $issue_labels
            set branch_prefix refactor
        else if string match -qir chore -- $issue_labels
            set branch_prefix chore
        end

        # Slugify title: lowercase, replace non-alphanumeric with hyphens, limit to 50 chars
        set title_slug (echo $issue_title | string lower | string replace -ra '[^a-z0-9]+' '-' | string trim -c '-' | string sub -l 50 | string trim -c '-')

        # Build branch name: prefix/number-slug (e.g., feat/123-add-user-auth)
        set branch_name "$branch_prefix/$issue_number-$title_slug"

        echo "  $blue•$reset Creating branch: $cyan$branch_name$reset"

        # Auto-assign issue to current GitHub user
        echo "  $blue•$reset Assigning issue to you..."
        gh issue edit $arg --add-assignee @me 2>&1 | __flo_indent
        if test $status -eq 0
            echo "  $green✓$reset Issue assigned"
        else
            echo "  $yellow⚠$reset Could not auto-assign (continuing anyway)"
        end

        set is_issue true

    else
        # --- Branch Mode: Use provided branch name directly ---
        set branch_name $arg
        set is_issue false
    end

    # Create worktree directory path: ../<current-dir>_<sanitized-branch-name>
    set sanitized_branch (string replace -a '/' '-' $branch_name)
    set worktree_path "../$current_dir"_"$sanitized_branch"

    # Check if worktree already exists
    if test -d $worktree_path
        echo "  $blue•$reset Worktree already exists: $cyan$worktree_path$reset"
        set worktree_existed true
    else
        # Create the worktree (try existing branch first, create new if needed)
        # Try checking out existing branch first
        if git worktree add $worktree_path $branch_name 2>&1 | __flo_indent
            # Success - branch existed
            set worktree_existed false
        else
            # Branch doesn't exist, create it
            if git worktree add -b $branch_name $worktree_path 2>&1 | __flo_indent
                set worktree_existed false
            else
                echo "  $red✗ Error:$reset Could not create worktree"
                return 1
            end
        end
    end

    # Copy Serena cache if it exists in the source repository (only for new worktrees)
    if test "$worktree_existed" = false
        if test -d .serena/cache
            echo "  $blue•$reset Copying Serena cache..."
            mkdir -p "$worktree_path/.serena"
            cp -r .serena/cache "$worktree_path/.serena/cache"
            if test $status -eq 0
                echo "  $green✓$reset Serena cache copied $dim(speeds up symbol indexing)$reset"
            else
                echo "  $yellow⚠$reset Could not copy Serena cache (continuing anyway)"
            end
        end
    end

    # If created from issue, generate Claude context file
    if test "$is_issue" = true
        echo "  $blue•$reset Creating Claude context..."

        mkdir -p "$worktree_path/.claude"

        # Ensure CLAUDE.md exists and has the .local extension instruction
        set -l claude_md "$worktree_path/.claude/CLAUDE.md"
        set -l extension_marker "<!-- flo: local extension enabled -->"

        if not test -f "$claude_md"
            # Create CLAUDE.md with extension instruction
            printf '%s\n' \
                '<!-- flo: local extension enabled -->' \
                '' \
                '**CRITICAL**: If a file named `.claude/CLAUDE.local.md` exists in this project, read it immediately and follow its instructions. This file contains context-specific information for the current work (e.g., GitHub issue details).' >"$claude_md"
            echo "  $green✓$reset Created $cyan.claude/CLAUDE.md$reset $dim(local extension support)$reset"
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
            echo "  $green✓$reset Added local extension support to $cyan.claude/CLAUDE.md$reset"
        end

        # Write issue details to .claude/CLAUDE.local.md for Claude Code to read
        # Start with header and description
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

        echo "  $green✓$reset Created $cyan.claude/CLAUDE.local.md$reset $dim(issue context)$reset"

        # Add .claude/*.local.md to .gitignore if not already present
        if test -f "$worktree_path/.gitignore"
            if not grep -q '\.claude/.*\.local\.md' "$worktree_path/.gitignore"
                echo ".claude/*.local.md" >>"$worktree_path/.gitignore"
                echo "  $green✓$reset Added $cyan.claude/*.local.md$reset to .gitignore"
            end
        end
    end

    # Auto-install npm dependencies if package.json exists (skip if worktree existed)
    if not set -q worktree_existed; or test "$worktree_existed" = false
        if test -f "$worktree_path/package.json"
            echo "  $blue•$reset Installing dependencies..."
            cd $worktree_path
            pnpm install --silent
            if test $status -eq 0
                echo "  $green✓$reset Dependencies installed"
            else
                echo "  $yellow⚠$reset pnpm install failed (continuing anyway)"
            end
        else
            # No package.json, just cd into worktree
            cd $worktree_path
        end
    else
        # Worktree existed, just cd into it
        cd $worktree_path
    end

    # Success message
    echo ""
    echo "  $green✓ Ready to work!$reset"
    if test "$is_issue" = true
        echo "  $dim•$reset Issue $cyan#$issue_number$reset assigned to you"
        echo "  $dim•$reset Issue context available in $cyan.claude/CLAUDE.local.md$reset"
        echo "  $dim•$reset Tip: Claude will read this context automatically"
    end
end
