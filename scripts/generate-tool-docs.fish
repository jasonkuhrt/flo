#!/usr/bin/env fish
# Generate tool documentation for external tools used by flo

set -l tool_docs_dir tool-docs

# Clean out old tool docs first
if test -d $tool_docs_dir
    command rm -rf $tool_docs_dir
end

# Create tool docs directory
mkdir -p $tool_docs_dir

echo "Generating tool documentation..."

# List of tools with their help commands
set -l tools \
    "bat:bat --help" \
    "fd:fd --help" \
    "gum-choose:gum choose --help" \
    "gum-filter:gum filter --help" \
    "gum-input:gum input --help" \
    "gum-spin:gum spin --help" \
    "gum-style:gum style --help" \
    "gum-table:gum table --help"

# Generate help for each tool
for tool_entry in $tools
    set -l parts (string split ":" $tool_entry)
    set -l tool_name $parts[1]
    set -l help_command (string join " " $parts[2..-1])

    echo "  Generating help for $tool_name..."

    # Try to run the help command and capture output
    set -l output_file "$tool_docs_dir/$tool_name.txt"

    if eval $help_command >$output_file 2>/dev/null
        echo "    ✓ Generated $output_file"
    else
        echo "    ✗ Failed to generate help for $tool_name (tool may not be installed)"
        echo "Help not available - tool may not be installed" >$output_file
    end
end

echo ""
echo "Tool documentation generated in $tool_docs_dir/"
echo ""
echo "Generated files:"
find $tool_docs_dir -name "*.txt" | sort | sed 's|^|  |'
echo ""
