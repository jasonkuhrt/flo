#!/usr/bin/env fish
# Format all Fish files in the project

set -l script_dir (dirname (status --current-filename))
set -l project_root (dirname $script_dir)

echo "Formatting Fish files..."

set -l files_formatted 0
set -l files_total 0

for file in $project_root/**/*.fish
    set files_total (math $files_total + 1)

    # Check if file needs formatting
    if not fish_indent --check $file >/dev/null 2>&1
        echo "  Formatting $(string replace $project_root/ '' $file)"
        fish_indent -w $file
        set files_formatted (math $files_formatted + 1)
    end
end

if test $files_formatted -eq 0
    echo "All $files_total Fish files are already properly formatted"
else
    echo "Formatted $files_formatted out of $files_total Fish files"
end
