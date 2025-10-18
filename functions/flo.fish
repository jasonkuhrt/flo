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

# Main command - create worktree from branch name or GitHub issue number
function flo_flo
    set current_dir (basename (pwd))
    set arg $argv[1]

    # Check if argument is an issue number (integer)
    if string match -qr '^\d+$' -- $arg
        # --- Issue Mode: Fetch from GitHub ---

        # Validate gh CLI is installed
        if not command -v gh >/dev/null 2>&1
            echo "✗ Error: gh CLI not installed"
            echo "Install with: brew install gh"
            echo "Or visit: https://cli.github.com"
            return 1
        end

        echo "• Fetching issue #$arg..."

        # Fetch issue data as JSON using gh CLI (including comments)
        set issue_json (gh issue view $arg --json number,title,body,labels,url,comments 2>/dev/null)

        if test $status -ne 0
            echo "✗ Error: Could not fetch issue #$arg"
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

        echo "• Creating branch: $branch_name"

        # Auto-assign issue to current GitHub user
        echo "• Assigning issue to you..."
        gh issue edit $arg --add-assignee @me 2>/dev/null
        if test $status -eq 0
            echo "✓ Issue assigned"
        else
            echo "⚠ Could not auto-assign (continuing anyway)"
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
        echo "• Worktree already exists: $worktree_path"
        set worktree_existed true
    else
        # Create the worktree (try existing branch first, create new if needed)
        git worktree add $worktree_path $branch_name 2>/dev/null
        or git worktree add -b $branch_name $worktree_path

        if test $status -ne 0
            echo "✗ Error: Could not create worktree"
            return 1
        end
        set worktree_existed false
    end

    # If created from issue, generate Claude context file
    if test "$is_issue" = true
        echo "• Creating Claude context..."

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
            echo "✓ Created .claude/CLAUDE.md with local extension support"
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
            echo "✓ Added local extension support to existing .claude/CLAUDE.md"
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

        echo "✓ Created .claude/CLAUDE.local.md with issue context"

        # Add .claude/*.local.md to .gitignore if not already present
        if test -f "$worktree_path/.gitignore"
            if not grep -q '\.claude/.*\.local\.md' "$worktree_path/.gitignore"
                echo ".claude/*.local.md" >>"$worktree_path/.gitignore"
                echo "✓ Added .claude/*.local.md to .gitignore"
            end
        end
    end

    # Auto-install npm dependencies if package.json exists (skip if worktree existed)
    if not set -q worktree_existed; or test "$worktree_existed" = false
        if test -f "$worktree_path/package.json"
            echo "• Installing dependencies..."
            cd $worktree_path
            pnpm install --silent
            if test $status -eq 0
                echo "✓ Dependencies installed"
            else
                echo "⚠ pnpm install failed (continuing anyway)"
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
    echo "✓ Ready to work!"
    if test "$is_issue" = true
        echo "• Issue #$issue_number assigned to you"
        echo "• Issue context available in .claude/CLAUDE.local.md"
        echo "• Tip: Claude will read this context automatically"
    end
end
