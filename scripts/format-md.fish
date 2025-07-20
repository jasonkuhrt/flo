#!/usr/bin/env fish
# Format all Markdown files in the project

set -l script_dir (dirname (status --current-filename))
set -l project_root (dirname $script_dir)

echo "Formatting Markdown files..."

# Check if dprint is available
if not command -v dprint >/dev/null 2>&1
    echo "ERROR: dprint not found. Please install dprint globally first."
    exit 1
end

# Use markdown plugin directly without config file
set -l markdown_plugin "https://plugins.dprint.dev/markdown-0.17.8.wasm"

set -l files_formatted 0
set -l files_total 0

for file in $project_root/**/*.md
    set files_total (math $files_total + 1)

    # Check if file needs formatting
    if not dprint check --plugins $markdown_plugin -- $file >/dev/null 2>&1
        echo "  Formatting $(string replace $project_root/ '' $file)"
        dprint fmt --plugins $markdown_plugin -- $file
        if test $status -eq 0
            set files_formatted (math $files_formatted + 1)
        else
            echo "ERROR: Failed to format $file"
            exit 1
        end
    end
end

if test $files_formatted -eq 0
    echo "All $files_total Markdown files are already properly formatted"
else
    echo "Formatted $files_formatted out of $files_total Markdown files"
end
