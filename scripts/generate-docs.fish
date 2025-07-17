#!/usr/bin/env fish
# Generate documentation from flo's actual command structure

set -l docs_dir docs
set -l reference_dir "$docs_dir/reference"

# Clean out old docs first
if test -d $reference_dir
    command rm -rf $reference_dir/*
end

# Create docs directories
mkdir -p $reference_dir

# Source the flo functions we need
source functions/flo.fish

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
    # Output help content line by line
    for line in $help_output
        echo "$line"
    end
    echo '```'
end

# Extract commands from the flo dispatcher switch statement
function extract_commands_from_dispatcher
    set -l commands_found
    set -l in_switch 0

    # Read the flo.fish file and extract case statements
    while read -l line
        # Look for the switch statement
        if string match -q "*switch*" "$line"
            set in_switch 1
            continue
        end

        # Exit when we hit the end of the switch
        if test $in_switch -eq 1 && string match -q "*end*" "$line"
            break
        end

        # Extract case statements
        if test $in_switch -eq 1 && string match -q "*case*" "$line"
            # Extract the command name after "case"
            set -l cmd_name (string match -r 'case\s+([a-zA-Z0-9_-]+)' "$line" | tail -1)
            if test -n "$cmd_name" && test "$cmd_name" != help && test "$cmd_name" != "'*'"
                set commands_found $commands_found $cmd_name
            end
        end
    end <functions/flo.fish

    # Output each command on a separate line to preserve array structure
    for cmd in $commands_found
        echo $cmd
    end
end

# Function to discover subcommands for a given command
function discover_subcommands
    set -l parent_cmd $argv[1]
    set -l subcommands

    # Check if there's a directory for this command
    if test -d "functions/$parent_cmd"
        # Look for subcommand files in the directory
        for file in functions/$parent_cmd/*.fish
            if test -f "$file"
                set -l subcmd (basename "$file" .fish)
                # Skip the main command file if it has the same name as the directory
                if test "$subcmd" != "$parent_cmd"
                    set subcommands $subcommands $subcmd
                end
            end
        end
    end

    # Special handling for claude command - it has a --clean flag that we treat as a subcommand
    if test "$parent_cmd" = claude
        set subcommands $subcommands clean
    end

    # Output each subcommand on a separate line
    for subcmd in $subcommands
        echo $subcmd
    end
end

# Function to generate help for a command or subcommand
function generate_command_help
    set -l cmd_path $argv[1]
    set -l output_file $argv[2]

    # Try to get help for the command
    set -l help_output

    if string match -q "*/*" "$cmd_path"
        # It's a subcommand
        set -l parts (string split "/" "$cmd_path")
        set -l main_cmd $parts[1]
        set -l subcmd $parts[2]

        # Try different ways to get subcommand help
        if test "$main_cmd" = claude && test "$subcmd" = clean
            # For claude-clean, create custom help since it's a flag not a subcommand
            set help_output "Usage: flo claude --clean"
            set help_output $help_output ""
            set help_output $help_output "Clean up old context files"
            set help_output $help_output ""
            set help_output $help_output "Examples:"
            set help_output $help_output "  flo claude --clean        # Clean old context files"
        else
            # Try as a regular subcommand
            set help_output (flo $main_cmd $subcmd --help 2>/dev/null)
        end

        if test -z "$help_output"
            set help_output (flo $main_cmd $subcmd 2>&1 | head -20)
        end

        set flo_cmd "flo $main_cmd $subcmd"
    else
        # It's a top-level command
        set help_output (flo $cmd_path --help 2>/dev/null)
        if test -z "$help_output"
            set help_output (flo $cmd_path 2>&1 | head -20)
        end

        set flo_cmd "flo $cmd_path"
    end

    if test -n "$help_output"
        help_to_markdown "$flo_cmd" $help_output >$output_file
        return 0
    else
        # Create a basic page even if no help is available
        help_to_markdown "$flo_cmd" >$output_file
        return 1
    end
end

# Start generation
gum log --level info "Generating documentation from flo command structure"

# Get the main help output
set -l main_help (flo help 2>/dev/null)

# Extract commands from dispatcher
set -l discovered_commands (extract_commands_from_dispatcher)

# Discover subcommands for each command
set -l all_command_paths
for cmd in $discovered_commands
    # Skip claude-clean as it's not a real command, just a function
    if test "$cmd" != claude-clean
        set all_command_paths $all_command_paths $cmd
    end

    set -l subcommands (discover_subcommands $cmd)
    if test (count $subcommands) -gt 0
        for subcmd in $subcommands
            set all_command_paths $all_command_paths "$cmd/$subcmd"
        end
    end
end

# Generate main help documentation
help_to_markdown flo $main_help >"$reference_dir/README.md"

# Generate documentation for each command and subcommand
for cmd_path in $all_command_paths
    set -l output_file ""

    if string match -q "*/*" $cmd_path
        # It's a subcommand - create directory structure
        set -l parts (string split "/" $cmd_path)
        set -l main_cmd $parts[1]
        set -l subcmd $parts[2]

        gum log --level info "Processing subcommand: $main_cmd $subcmd"
        mkdir -p "$reference_dir/$main_cmd"
        set output_file "$reference_dir/$main_cmd/$subcmd.md"
    else
        # It's a top-level command
        gum log --level info "Processing command: $cmd_path"
        set output_file "$reference_dir/$cmd_path.md"
    end

    generate_command_help $cmd_path $output_file
end

# Generate main reference index (append to existing content)
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

# Generate command links dynamically from discovered commands
for cmd in $discovered_commands
    # Get the command description from help output
    set -l desc ""
    for line in $main_help
        if string match -q "*$cmd*" "$line"
            # Extract description after the command (look for multiple spaces)
            set -l full_line (string trim "$line")
            if string match -q "*$cmd*" "$full_line"
                # Split on multiple spaces and take the last part
                set -l parts (string split -r -m 1 "  " "$full_line")
                if test (count $parts) -eq 2
                    set desc $parts[2]
                end
            end
            break
        end
    end

    # Check if command has subcommands
    set -l has_subcommands 0
    for cmd_path in $all_command_paths
        if string match -q "$cmd/*" $cmd_path
            set has_subcommands 1
            break
        end
    end

    if test $has_subcommands -eq 1
        echo "- [$cmd]($cmd/) - $desc" >>$reference_dir/README.md

        # Generate index for subcommands
        echo "# flo $cmd" >"$reference_dir/$cmd/README.md"
        echo "" >>"$reference_dir/$cmd/README.md"
        echo "$desc" >>"$reference_dir/$cmd/README.md"
        echo "" >>"$reference_dir/$cmd/README.md"
        echo "## Subcommands" >>"$reference_dir/$cmd/README.md"
        echo "" >>"$reference_dir/$cmd/README.md"

        for cmd_path in $all_command_paths
            if string match -q "$cmd/*" $cmd_path
                set -l subcmd (string replace "$cmd/" "" $cmd_path)
                echo "- [$subcmd]($subcmd.md)" >>"$reference_dir/$cmd/README.md"
            end
        end
    else
        echo "- [$cmd]($cmd.md) - $desc" >>$reference_dir/README.md
    end
end

# Generate main docs index
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
    '- **Pull Request Creation** - Create PRs with automatic branch pushing' \
    '- **Workflow Automation** - Seamless transitions between issues with next command' \
    '- **Claude Integration** - Generate context for Claude AI assistance' \
    '- **Smart Completions** - Tab completion for all commands and GitHub data' \
    '' \
    '## Command Structure' \
    '' \
    'flo supports both top-level commands and subcommands:' \
    '' \
    '```' \
    'flo <command>                    # Top-level command' \
    'flo <command> <subcommand>       # Subcommand' \
    '```' \
    '' \
    '## Directory Structure' \
    '' \
    'Commands are organized in the codebase as follows:' \
    '' \
    '```' \
    'functions/                       # Command directory (should be renamed to commands/)' \
    '├── <command>.fish              # Top-level command' \
    '├── <command>/                  # Subcommand directory' \
    '│   ├── <subcommand>.fish      # Individual subcommand' \
    '│   └── ...                    # More subcommands' \
    '└── helpers/                   # Helper functions' \
    '    └── __flo_*.fish           # Internal helpers' \
    '```' \
    '' \
    '## Command Definition Convention' \
    '' \
    'All commands follow this consistent pattern:' \
    '' \
    '```fish' \
    'function <command_name> --description "Brief description"' \
    '    argparse --name="flo <command>" h/help [flags...] -- $argv; or return' \
    '    ' \
    '    if set -q _flag_help' \
    '        # Help text implementation' \
    '        return 0' \
    '    end' \
    '    ' \
    '    # Command implementation' \
    end \
    '```' \
    '' \
    '**Key conventions:**' \
    '- Commands are in `functions/<command>.fish` (or `functions/<command>/` for subcommands)' \
    '- All commands use `argparse --name="flo <command>"`' \
    '- All commands support `-h/--help` flag' \
    '- Commands are routed through the main dispatcher in `flo.fish`' \
    '- Help text is self-contained within each command' \
    '- Subcommands are organized in subdirectories' \
    '' \
    '## Command Overview' \
    '' \
    '```' >"$docs_dir/README.md"

# Append the actual help output
for line in $main_help
    echo $line >>"$docs_dir/README.md"
end

printf '%s\n' \
    '```' \
    '' \
    'For detailed command documentation, see the [Command Reference](reference/).' \
    '' \
    '## Recommended Improvements' \
    '' \
    '1. **Rename directory**: `functions/` → `commands/`' \
    '2. **Implement proper subcommands**: `flo claude clean` instead of `flo claude --clean`' \
    '3. **Organize subcommands**: Move related commands into subdirectories' \
    '4. **Consistent naming**: Use subcommand structure instead of hyphenated commands' \
    '' >>"$docs_dir/README.md"

# Final summary
set -l file_count (find $reference_dir -name "*.md" | wc -l | string trim)
set -l cmd_count (count $discovered_commands)

echo ""
gum style --foreground 2 "Documentation generated successfully"
echo ""
echo "Summary:"
echo "  Commands: $cmd_count"
echo "  Files: $file_count"
echo "  Output: $docs_dir/"
echo ""

# Show the final directory structure
echo "Final docs structure:"
if command -q tree
    tree $docs_dir -I "*.tmp"
else
    find $docs_dir -type f -name "*.md" | sort | sed 's|^'$docs_dir'/||'
end
echo ""
