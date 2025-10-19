#!/usr/bin/env fish

# Generate README reference section from --help output

set readme README.md
set start_marker "<!-- REFERENCE_START -->"
set end_marker "<!-- REFERENCE_END -->"
set temp_output (mktemp)
set temp_content (mktemp)

# Build the reference content by capturing help output
echo "## Reference" >$temp_content
echo "" >>$temp_content
echo "Run any command with \`--help\` for detailed help." >>$temp_content
echo "" >>$temp_content

echo "### "'`flo`' >>$temp_content
echo "" >>$temp_content
echo '```' >>$temp_content
fish -c "flo --help" 2>&1 | perl -pe 's/\e\[[0-9;]*[mGKH]//g; s/\e\([B0]//g' >>$temp_content
echo '```' >>$temp_content
echo "" >>$temp_content

echo "### "'`flo list`' >>$temp_content
echo "" >>$temp_content
echo '```' >>$temp_content
fish -c "flo list --help" 2>&1 | perl -pe 's/\e\[[0-9;]*[mGKH]//g; s/\e\([B0]//g' >>$temp_content
echo '```' >>$temp_content
echo "" >>$temp_content

echo "### "'`flo rm`' >>$temp_content
echo "" >>$temp_content
echo '```' >>$temp_content
fish -c "flo rm --help" 2>&1 | perl -pe 's/\e\[[0-9;]*[mGKH]//g; s/\e\([B0]//g' >>$temp_content
echo '```' >>$temp_content
echo "" >>$temp_content

echo "### "'`flo prune`' >>$temp_content
echo "" >>$temp_content
echo '```' >>$temp_content
fish -c "flo prune --help" 2>&1 | perl -pe 's/\e\[[0-9;]*[mGKH]//g; s/\e\([B0]//g' >>$temp_content
echo '```' >>$temp_content

# Replace content between markers
set in_section 0
while read -l line
    if test "$in_section" -eq 0
        echo "$line" >>$temp_output
        if string match -q "*$start_marker*" -- "$line"
            cat $temp_content >>$temp_output
            set in_section 1
        end
    else
        if string match -q "*$end_marker*" -- "$line"
            echo "$line" >>$temp_output
            set in_section 0
        end
    end
end <$readme

mv $temp_output $readme
rm $temp_content

echo "✓ Updated README reference section"
