#!/usr/bin/env fish
# Check if all Fish files are properly formatted

set -l script_dir (dirname (status --current-filename))
set -l project_root (dirname $script_dir)

echo "🔍 Checking Fish file formatting..."

set -l files_need_formatting 0
set -l files_total 0

for file in $project_root/**/*.fish
    set files_total (math $files_total + 1)

    if not fish_indent --check $file >/dev/null 2>&1
        echo "  ❌ $(string replace $project_root/ '' $file) needs formatting"
        set files_need_formatting (math $files_need_formatting + 1)
    end
end

if test $files_need_formatting -eq 0
    echo "✅ All $files_total Fish files are properly formatted"
    exit 0
else
    echo "❌ $files_need_formatting out of $files_total Fish files need formatting"
    echo ""
    echo "Run './scripts/format.fish' to fix formatting"
    exit 1
end
