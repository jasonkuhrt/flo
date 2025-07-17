#!/usr/bin/env fish
# Generate documentation from flo's internal --help output

set -l docs_dir docs
set -l reference_dir "$docs_dir/reference"

# Clean out old docs first
if test -d $reference_dir
    echo "🧹 Cleaning old documentation..."
    rm -rf $reference_dir/*
end

# Create docs directories
mkdir -p $reference_dir

# Source the flo loader to make commands available
source functions/flo.fish

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
help_to_markdown flo $main_help >"$reference_dir/README.md"

# Define command structure with subcommands
# Note: issue-create is a hyphenated command, not a subcommand
set -l command_structure \
    issue \
    issue-create \
    pr \
    pr/create \
    pr/push \
    pr/checks \
    pr/merge \
    worktree \
    worktree/create \
    worktree/delete \
    worktree/list \
    worktree/switch \
    list \
    list/issues \
    list/prs \
    list/worktrees \
    status \
    projects \
    claude \
    next

# Generate documentation for each command/subcommand
for cmd_path in $command_structure
    set -l flo_cmd ""
    set -l output_path ""

    # Check if it's a hyphenated command or a subcommand
    if string match -q "*/*" $cmd_path
        # It's a subcommand (e.g., pr/create)
        set -l parts (string split "/" $cmd_path)

        # Build the flo command
        set flo_cmd flo
        for part in $parts
            set flo_cmd "$flo_cmd $part"
        end

        # Create directory structure
        set -l dir_path $reference_dir
        for i in (seq 1 (math (count $parts) - 1))
            set dir_path "$dir_path/$parts[$i]"
            mkdir -p $dir_path
        end
        set output_path "$dir_path/$parts[-1].md"
    else
        # It's a top-level command (possibly hyphenated like issue-create)
        set flo_cmd "flo $cmd_path"
        set output_path "$reference_dir/$cmd_path.md"
    end

    echo "📝 Generating help for: $flo_cmd"

    # Try to get help for the command
    set -l help_output (eval $flo_cmd --help 2>/dev/null)

    if test -z "$help_output"
        # If no --help flag, try to get help from the command itself
        set help_output (eval $flo_cmd 2>&1 | head -20)
    end

    if test -n "$help_output"
        help_to_markdown "$flo_cmd" $help_output >$output_path
    else
        echo "⚠️  No help output found for: $flo_cmd"
    end
end

# Generate index files for directories with subcommands
function generate_index --description "Generate index.md for a directory"
    set -l dir_path $argv[1]
    set -l cmd_name $argv[2]
    set -l cmd_desc $argv[3]

    set -l index_file "$dir_path/README.md"

    echo "# flo $cmd_name" >$index_file
    echo "" >>$index_file
    echo "$cmd_desc" >>$index_file
    echo "" >>$index_file
    echo "## Subcommands" >>$index_file
    echo "" >>$index_file

    # List all .md files in the directory
    for file in $dir_path/*.md
        if test -f $file -a (basename $file) != "README.md"
            set -l subcmd (basename $file .md)
            echo "- [$subcmd]($subcmd.md)" >>$index_file
        end
    end
end

# Generate index files for command directories
echo "📝 Generating index files for command directories..."
if test -d "$reference_dir/issue"
    generate_index "$reference_dir/issue" issue "GitHub issue management commands"
end
if test -d "$reference_dir/pr"
    generate_index "$reference_dir/pr" pr "Pull request management commands"
end
if test -d "$reference_dir/worktree"
    generate_index "$reference_dir/worktree" worktree "Git worktree management commands"
end
if test -d "$reference_dir/list"
    generate_index "$reference_dir/list" list "Commands for listing various items"
end

# Generate main reference index
echo "📝 Generating main reference index..."
echo "" >>$reference_dir/README.md
echo "# flo Command Reference" >>$reference_dir/README.md
echo "" >>$reference_dir/README.md
echo "This directory contains auto-generated documentation from flo's internal \`--help\` output." >>$reference_dir/README.md
echo "" >>$reference_dir/README.md
echo "## Main Command" >>$reference_dir/README.md
echo "" >>$reference_dir/README.md
echo "The main flo help documentation is above." >>$reference_dir/README.md
echo "" >>$reference_dir/README.md
echo "## Commands" >>$reference_dir/README.md
echo "" >>$reference_dir/README.md
echo "### Core Commands" >>$reference_dir/README.md
echo "- [issue](issue.md) - Work on GitHub issues" >>$reference_dir/README.md
echo "- [issue-create](issue-create.md) - Create new issues and start working" >>$reference_dir/README.md
echo "- [pr/](pr/) - Pull request management" >>$reference_dir/README.md
if test -d "$reference_dir/pr"
    echo "  - [create](pr/create.md) - Create pull requests" >>$reference_dir/README.md
    echo "  - [push](pr/push.md) - Push current branch" >>$reference_dir/README.md
    echo "  - [checks](pr/checks.md) - Check PR status" >>$reference_dir/README.md
    echo "  - [merge](pr/merge.md) - Merge pull requests" >>$reference_dir/README.md
end
echo "- [worktree/](worktree/) - Git worktree management" >>$reference_dir/README.md
if test -d "$reference_dir/worktree"
    echo "  - [create](worktree/create.md) - Create worktrees" >>$reference_dir/README.md
    echo "  - [delete](worktree/delete.md) - Delete worktrees" >>$reference_dir/README.md
    echo "  - [list](worktree/list.md) - List worktrees" >>$reference_dir/README.md
    echo "  - [switch](worktree/switch.md) - Switch worktrees" >>$reference_dir/README.md
end
echo "" >>$reference_dir/README.md
echo "### Browse Commands" >>$reference_dir/README.md
echo "- [list/](list/) - List various items" >>$reference_dir/README.md
if test -d "$reference_dir/list"
    echo "  - [issues](list/issues.md) - List GitHub issues" >>$reference_dir/README.md
    echo "  - [prs](list/prs.md) - List pull requests" >>$reference_dir/README.md
    echo "  - [worktrees](list/worktrees.md) - List worktrees" >>$reference_dir/README.md
end
echo "- [status](status.md) - Show status information" >>$reference_dir/README.md
echo "- [projects](projects.md) - List GitHub projects" >>$reference_dir/README.md
echo "" >>$reference_dir/README.md
echo "### Workflow Commands" >>$reference_dir/README.md
echo "- [claude](claude.md) - Claude AI integration" >>$reference_dir/README.md
echo "- [next](next.md) - Context-aware next issue command" >>$reference_dir/README.md
echo "" >>$reference_dir/README.md
echo "## Navigation" >>$reference_dir/README.md
echo "" >>$reference_dir/README.md
echo "Commands with subcommands have their own directories:" >>$reference_dir/README.md
echo "- \`pr/\` - Pull request commands" >>$reference_dir/README.md
echo "- \`worktree/\` - Worktree commands" >>$reference_dir/README.md
echo "- \`list/\` - List commands" >>$reference_dir/README.md
echo "" >>$reference_dir/README.md
echo "Each directory contains a README.md with an overview and links to subcommand documentation." >>$reference_dir/README.md

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
    '  - Commands are organized hierarchically with subcommands in subdirectories' \
    '  - For example: `flo pr create` documentation is at `reference/pr/create.md`' \
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
    '  next [number]           Transition to next issue (context-aware)' \
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
echo "📂 Directory structure:"
find $reference_dir -type d | sort | while read -l dir
    set -l indent (string repeat -n (math (string split "/" $dir | count) - 3) "  ")
    echo "$indent$(basename $dir)/"
end
echo ""
echo "📄 Generated files:"
find $reference_dir -name "*.md" | sort
