#!/usr/bin/env fish
# Format all Markdown files in the project

set -l script_dir (dirname (status --current-filename))
set -l project_root (dirname $script_dir)

echo "🎨 Formatting Markdown files..."

set -l files_formatted 0
set -l files_total 0

# Check if prettier is available
if not command -v prettier >/dev/null 2>&1
    echo "⚠️  prettier not found, skipping markdown formatting"
    echo "   Install with: npm install -g prettier"
    exit 0
end

for file in $project_root/**/*.md
    set files_total (math $files_total + 1)

    # Check if file needs formatting
    if not prettier --check $file >/dev/null 2>&1
        echo "  Formatting $(string replace $project_root/ '' $file)"
        prettier --write $file >/dev/null 2>&1
        set files_formatted (math $files_formatted + 1)
    end
end

if test $files_formatted -eq 0
    echo "✅ All $files_total Markdown files are already properly formatted"
else
    echo "✅ Formatted $files_formatted out of $files_total Markdown files"
end
