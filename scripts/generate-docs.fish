#!/usr/bin/env fish
# Generate documentation from flo's internal --help output

set -l docs_dir docs
set -l reference_dir "$docs_dir/reference"

# Create docs directories
mkdir -p $reference_dir

# Source the flo loader to make commands available
source functions/loader.fish

echo "Generating documentation from --help output..."

# Helper function to convert help output to markdown
function help_to_markdown --description "Convert help output to markdown format"
    set -l title $argv[1]
    set -l help_output $argv[2..-1]

    echo "# $title"
    echo ""

    # Check if we have actual help content
    if test -z "$help_output"
        echo "No help available for this command."
        return
    end

    echo '```'
    # Format the help output with proper line breaks
    for line in $help_output
        echo $line
    end
    echo '```'
end

# Generate main help documentation
echo "📝 Generating main help..."
set -l main_help (flo help 2>/dev/null)
help_to_markdown flo $main_help >"$reference_dir/flo.md"

# Generate command-specific help documentation
set -l commands issue issue-create pr worktree list status projects claude claude-clean

for cmd in $commands
    echo "📝 Generating help for: $cmd"

    # Try to get help for the command
    set -l help_output (flo $cmd --help 2>/dev/null)

    if test -z "$help_output"
        # If no --help flag, try to get help from the command itself
        set help_output (flo $cmd 2>&1 | head -20)
    end

    if test -n "$help_output"
        help_to_markdown "flo $cmd" $help_output >"$reference_dir/$cmd.md"
    else
        echo "⚠️  No help output found for: $cmd"
    end
end

# Generate help for subcommands
set -l subcommands
set -l subcommands $subcommands "pr create" "pr push" "pr checks" "pr merge"
set -l subcommands $subcommands "worktree create" "worktree delete" "worktree list" "worktree switch"
set -l subcommands $subcommands "list issues" "list prs" "list worktrees"

for subcmd in $subcommands
    set -l parts (string split " " $subcmd)
    set -l cmd $parts[1]
    set -l action $parts[2]

    echo "📝 Generating help for: $cmd $action"

    # Try to get help for the subcommand
    set -l help_output (flo $cmd $action --help 2>/dev/null)

    if test -z "$help_output"
        # Try alternative help patterns
        set help_output (flo $cmd $action 2>&1 | head -20)
    end

    if test -n "$help_output"
        set -l filename (string replace " " "-" $subcmd)
        help_to_markdown "flo $subcmd" $help_output >"$reference_dir/$filename.md"
    else
        echo "⚠️  No help output found for: $cmd $action"
    end
end

# Generate index file using printf
echo "📝 Generating index..."
printf '%s\n' \
    '# flo Command Reference' \
    '' \
    'This directory contains auto-generated documentation from flo'\''s internal `--help` output.' \
    '' \
    '## Commands' \
    '' \
    '### Core Commands' \
    '- [flo](flo.md) - Main command help' \
    '- [issue](issue.md) - Work on GitHub issues' \
    '- [issue-create](issue-create.md) - Create new issues' \
    '- [pr](pr.md) - Pull request management' \
    '- [worktree](worktree.md) - Git worktree management' \
    '' \
    '### Browse Commands' \
    '- [list](list.md) - List various items' \
    '- [status](status.md) - Show status information' \
    '- [projects](projects.md) - List GitHub projects' \
    '' \
    '### Workflow Commands' \
    '- [claude](claude.md) - Claude AI integration' \
    '- [claude-clean](claude-clean.md) - Clean Claude context files' \
    '' \
    '### Subcommands' \
    '' \
    '#### Pull Request Management' \
    '- [pr create](pr-create.md) - Create pull requests' \
    '- [pr push](pr-push.md) - Push current branch' \
    '- [pr checks](pr-checks.md) - Check PR status' \
    '- [pr merge](pr-merge.md) - Merge pull requests' \
    '' \
    '#### Worktree Management' \
    '- [worktree create](worktree-create.md) - Create worktrees' \
    '- [worktree delete](worktree-delete.md) - Delete worktrees' \
    '- [worktree list](worktree-list.md) - List worktrees' \
    '- [worktree switch](worktree-switch.md) - Switch worktrees' \
    '' \
    '#### List Commands' \
    '- [list issues](list-issues.md) - List GitHub issues' \
    '- [list prs](list-prs.md) - List pull requests' \
    '- [list worktrees](list-worktrees.md) - List worktrees' >"$reference_dir/README.md"

# Generate main docs index
echo "📝 Generating main docs index..."
printf '%s\n' \
    '# flo Documentation' \
    '' \
    'Welcome to the flo documentation. flo is a Git workflow automation tool that integrates with GitHub for seamless issue and pull request management.' \
    '' \
    '## Documentation Structure' \
    '' \
    '- **[Command Reference](reference/)** - Complete command documentation generated from `--help` output' \
    '- **Installation** - See main [README.md](../README.md) for installation instructions' \
    '- **Getting Started** - See main [README.md](../README.md) for quick start guide' \
    '' \
    '## Key Features' \
    '' \
    '- **Issue Workflow** - Start work on GitHub issues with automatic worktree creation' \
    '- **Pull Request Management** - Create, push, and merge PRs with status checking' \
    '- **Worktree Management** - Manage Git worktrees with ease' \
    '- **Claude Integration** - Generate context for Claude AI assistance' \
    '- **Smart Completions** - Tab completion for all commands and GitHub data' \
    '' \
    '## Architecture' \
    '' \
    'flo is built with a modular architecture using Fish shell:' \
    '' \
    '- **Domain-based modules** - Each feature area has its own file' \
    '- **Modern Fish patterns** - Uses native Fish operations for performance' \
    '- **Extensible design** - Easy to add new commands and features' \
    '' \
    '## Command Overview' \
    '' \
    '```' \
    'flo - Git workflow automation tool' \
    '' \
    'Commands:' \
    '  issue <number|title>    Start work on a GitHub issue' \
    '  issue-create <title>    Create a new issue and start working on it' \
    '  pr [create|push|checks|merge]  Manage pull requests' \
    '  worktree <create|delete|list|switch>  Manage git worktrees' \
    '  list <issues|prs|worktrees>  List various items' \
    '  status                  Show current worktree and PR status' \
    '  projects                List GitHub projects' \
    '  claude                  Add current branch context to Claude' \
    '  claude-clean            Remove old Claude context files' \
    '  help                    Show this help message' \
    '```' \
    '' \
    'For detailed command documentation, see the [Command Reference](reference/).' \
    '' >"$docs_dir/README.md"

echo ""
echo "✅ Documentation generation complete!"
echo "📁 Generated files in: $docs_dir"
echo "   - Main index: $docs_dir/README.md"
echo "   - Reference docs: $reference_dir/"
echo ""
echo "📖 To view documentation:"
echo "   - Browse: $reference_dir/README.md"
echo "   - Main docs: $docs_dir/README.md"
