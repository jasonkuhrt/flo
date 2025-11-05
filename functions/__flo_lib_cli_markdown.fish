# Markdown utilities for CLI framework

# Set framework directory if not already set (for standalone sourcing)
if not set -q __cli_framework_dir
    set -g __cli_framework_dir (dirname (status --current-filename))
end

function __cli_has_glow --description "Check if glow is available for markdown rendering"
    # Cache result to avoid repeated command lookups
    if not set -q __CLI_HAS_GLOW
        if command -q glow
            set -g __CLI_HAS_GLOW true
        else
            set -g __CLI_HAS_GLOW false
        end
    end
    test "$__CLI_HAS_GLOW" = true
end

function __cli_parse_frontmatter --description "Parse JSON frontmatter from markdown file"
    set -l file $argv[1]
    set -l key $argv[2]

    if not test -f "$file"
        return 1
    end

    # Extract JSON between --- delimiters and parse with jq
    set -l json (sed -n '/^---$/,/^---$/p' "$file" | sed '1d;$d')

    if test -z "$json"
        return 1
    end

    # Use jq to extract the key (returns empty string if not found)
    echo "$json" | jq -r ".$key // empty" 2>/dev/null
end

function __cli_get_markdown_content --description "Get markdown content without frontmatter"
    set -l file $argv[1]

    if not test -f "$file"
        return 1
    end

    # Skip frontmatter and output the rest
    set -l in_frontmatter false
    set -l frontmatter_ended false

    while read -l line
        # Handle frontmatter delimiters
        if test "$line" = ---
            if test "$in_frontmatter" = false
                set in_frontmatter true
                continue
            else if test "$frontmatter_ended" = false
                # End of frontmatter
                set frontmatter_ended true
                continue
            end
        end

        # Output lines after frontmatter
        if test "$frontmatter_ended" = true
            echo "$line"
        end
    end <"$file"
end

function __cli_render_markdown_sections --description "Parse and render markdown content with section headers"
    # Process the content line by line ($argv contains all lines as separate arguments)
    set -l current_section ""
    set -l in_section false
    set -l started false # Track if we've output any content yet

    for line in $argv
        # Skip leading blank lines
        if test "$started" = false -a -z "$line"
            continue
        end
        set started true
        # Check if line is a markdown heading (# Something)
        if string match -qr '^# (.+)$' -- $line
            set -l heading (string replace -r '^# (.+)$' '$1' -- $line | string trim)
            # Convert to uppercase for section header
            set heading (string upper -- $heading)

            # Output section header (dimmest with dim black)
            echo ""
            set_color --dim black
            echo "$heading"
            set_color normal
            set in_section true
        else
            # Regular content - indent if in a section
            if test "$in_section" = true
                # Only indent non-empty lines
                if test -n "$line"
                    echo "  $line"
                else
                    echo ""
                end
            else
                # Before any section, output as-is
                echo "$line"
            end
        end
    end
end

function __cli_find_command_doc --description "Find co-located markdown file for a command"
    set -l cmd $argv[1]

    # Check in the CLI directory (works for both dev and installed)
    if test -n "$__cli_dir"
        set -l doc_file "$__cli_dir/$cmd.md"
        if test -f "$doc_file"
            echo "$doc_file"
            return 0
        end
    end

    return 1
end

function __cli_render_usage --description "Generate usage section from frontmatter"
    set -l cmd $argv[1]
    set -l json $argv[2]

    set -l output ""
    set -a output "## Usage"
    set -a output ""
    set -a output '```'

    # Build usage line: command [OPTIONS] [ARGUMENTS]
    set -l usage_line "./$cmd"

    # Add [OPTIONS] if there are named parameters
    set -l named_count (echo "$json" | jq -r '.parametersNamed | length' 2>/dev/null)
    if test "$named_count" -gt 0
        set usage_line "$usage_line [OPTIONS]"
    end

    # Add positional parameters
    for param_json in (echo "$json" | jq -c '.parametersPositional[]?')
        set -l name (echo "$param_json" | jq -r '.name')
        set -l required (echo "$param_json" | jq -r 'if has("required") then .required else false end')

        if test "$required" = true
            set usage_line "$usage_line <$name>"
        else
            set usage_line "$usage_line [<$name>]"
        end
    end

    set -a output "$usage_line"
    set -a output '```'
    set -a output ""

    printf "%s\n" $output
end

function __cli_render_parameters_positional --description "Generate markdown table for positional parameters"
    set -l json $argv[1]

    set -l param_count (echo "$json" | jq -r '.parametersPositional | length' 2>/dev/null)
    if test "$param_count" -gt 0
        set -l output ""
        set -a output "## Positional Parameters"
        set -a output ""
        set -a output "| Parameter | Description |"
        set -a output "|-----------|-------------|"

        for param_json in (echo "$json" | jq -c '.parametersPositional[]')
            set -l name (echo "$param_json" | jq -r '.name')
            set -l desc (echo "$param_json" | jq -r '.description')

            set -a output "| `<$name>` | $desc |"
        end
        set -a output ""

        printf "%s\n" $output
    end
end

function __cli_render_parameters_named --description "Generate markdown table for named parameters"
    set -l json $argv[1]

    set -l param_count (echo "$json" | jq -r '.parametersNamed | length' 2>/dev/null)
    if test "$param_count" -gt 0
        set -l output ""
        set -a output "## Named Parameters"
        set -a output ""
        set -a output "| Flag | Description |"
        set -a output "|------|-------------|"

        for param_json in (echo "$json" | jq -c '.parametersNamed[]')
            set -l name (echo "$param_json" | jq -r '.name')
            set -l short (echo "$param_json" | jq -r '.short // empty')
            set -l desc (echo "$param_json" | jq -r '.description')

            # Build flag column: `--name` `-s` or just `--name`
            set -l flag_text
            if test -n "$short"
                set flag_text "`$name` `$short`"
            else
                set flag_text "`$name`"
            end

            set -a output "| $flag_text | $desc |"
        end
        set -a output ""

        printf "%s\n" $output
    end
end

function __cli_render_examples --description "Generate markdown for examples section"
    set -l json $argv[1]

    set -l example_count (echo "$json" | jq -r '.examples | length' 2>/dev/null)
    if test "$example_count" -gt 0
        set -l output ""
        set -a output "## Examples"
        set -a output ""

        for example_json in (echo "$json" | jq -c '.examples[]')
            set -l command (echo "$example_json" | jq -r '.command')
            set -l desc (echo "$example_json" | jq -r '.description // empty')

            if test -n "$desc"
                set -a output "$desc:"
            end
            set -a output '```fish'
            set -a output "$command"
            set -a output '```'
            set -a output ""
        end

        printf "%s\n" $output
    end
end

function __cli_render_related --description "Render related commands section"
    set -l json $argv[1]

    set -l related (echo "$json" | jq -r '.related[]?' 2>/dev/null)
    if test -n "$related"
        set_color --dim black
        echo "SEE ALSO"
        set_color normal
        for cmd in $related
            echo "  flo $cmd"
        end
        echo ""
    end
end

function __cli_render_exit_codes --description "Generate markdown table for exit codes section"
    set -l json $argv[1]

    # Check if exitCodes object exists and has keys
    set -l has_codes (echo "$json" | jq -r '.exitCodes | if . then keys | length else 0 end' 2>/dev/null)
    if test "$has_codes" -gt 0
        set -l output ""
        set -a output "## Exit Codes"
        set -a output ""
        set -a output "| Code | Description |"
        set -a output "|------|-------------|"

        for code_json in (echo "$json" | jq -c '.exitCodes | to_entries | sort_by(.key | tonumber) | .[]')
            set -l code (echo "$code_json" | jq -r '.key')
            set -l desc (echo "$code_json" | jq -r '.value')

            set -a output "| `$code` | $desc |"
        end
        set -a output ""

        printf "%s\n" $output
    end
end

function __cli_generate_help_markdown --description "Generate complete markdown document from frontmatter and guide content"
    set -l cmd $argv[1]
    set -l doc_file $argv[2]

    if not test -f "$doc_file"
        return 1
    end

    # Extract JSON frontmatter
    set -l json (sed -n '/^---$/,/^---$/p' "$doc_file" | sed '1d;$d')
    if test -z "$json"
        return 1
    end

    set -l output ""

    # Title
    if test "$__cli_name" = "$cmd"
        set -a output "# $cmd"
    else
        set -a output "# $__cli_name $cmd"
    end
    set -a output ""

    # Description
    set -l desc (echo "$json" | jq -r '.description // empty' 2>/dev/null)
    if test -n "$desc"
        set -a output "$desc"
        set -a output ""
    end

    # Usage section (auto-generated from parameters)
    set -l usage_md (__cli_render_usage $cmd "$json")
    if test -n "$usage_md"
        set -a output $usage_md
    end

    # Positional parameters table
    set -l positional_md (__cli_render_parameters_positional "$json")
    if test -n "$positional_md"
        set -a output $positional_md
    end

    # Named parameters table
    set -l named_md (__cli_render_parameters_named "$json")
    if test -n "$named_md"
        set -a output $named_md
    end

    # Guide content (markdown body without frontmatter)
    # Downgrade any H1 headings to H2 (H1 is reserved for command title)
    set -l guide_content (__cli_get_markdown_content "$doc_file" | sed 's/^# /## /')
    if test (count $guide_content) -gt 0
        set -a output $guide_content
    end

    # Examples
    set -l examples_md (__cli_render_examples "$json")
    if test -n "$examples_md"
        set -a output $examples_md
    end

    # Exit codes
    set -l exit_codes_md (__cli_render_exit_codes "$json")
    if test -n "$exit_codes_md"
        set -a output $exit_codes_md
    end

    printf "%s\n" $output
end

function __cli_render_command_help --description "Render formatted help for a command from markdown"
    set -l cmd $argv[1]
    set -l doc_file $argv[2]

    if not test -f "$doc_file"
        return 1
    end

    # Leading newline for spacing
    echo ""

    # Check if glow is available for full markdown rendering
    if __cli_has_glow
        # Generate complete markdown document and render with glow using local style
        __cli_generate_help_markdown $cmd $doc_file | glow -s "$__cli_framework_dir/cli_style.json"
    else
        # Fall back to custom rendering
        # Extract JSON frontmatter
        set -l json (sed -n '/^---$/,/^---$/p' "$doc_file" | sed '1d;$d')
        if test -z "$json"
            return 1
        end

        # Get description
        set -l desc (echo "$json" | jq -r '.description // empty' 2>/dev/null)

        # Title (command name in cyan)
        set_color cyan
        if test "$__cli_name" = "$cmd"
            echo "$cmd"
        else
            echo "$__cli_name $cmd"
        end
        set_color normal
        echo ""

        # Description paragraph
        if test -n "$desc"
            echo "$desc"
            echo ""
        end

        # Render POSITIONAL PARAMETERS section
        set -l param_count (echo "$json" | jq -r '.parametersPositional | length' 2>/dev/null)
        if test "$param_count" -gt 0
            set_color --dim black
            echo "POSITIONAL PARAMETERS"
            set_color normal
            echo "$json" | jq -r '.parametersPositional[] | "  <\(.name)>    \(.description)"' 2>/dev/null
            echo ""
        end

        # Render NAMED PARAMETERS section (old rendering style)
        set -l param_count (echo "$json" | jq -r '.parametersNamed | length' 2>/dev/null)
        if test "$param_count" -gt 0
            set_color --dim black
            echo "NAMED PARAMETERS"
            set_color normal
            echo "$json" | jq -r '.parametersNamed[] | "  \(.name)\(if .short then ", \(.short)" else "" end)    \(.description)"' 2>/dev/null
            echo ""
        end

        # Fall back to custom rendering for guide content
        set -l guide_content (__cli_get_markdown_content "$doc_file")
        if test (count $guide_content) -gt 0
            __cli_render_markdown_sections $guide_content
        end

        # Render examples (old style)
        set -l example_count (echo "$json" | jq -r '.examples | length' 2>/dev/null)
        if test "$example_count" -gt 0
            set_color --dim black
            echo EXAMPLES
            set_color normal
            echo "$json" | jq -r '.examples[] | "  \(.command)\(if .description then "    # \(.description)" else "" end)"' 2>/dev/null
            echo ""
        end

        # Render related commands
        __cli_render_related "$json"

        # Render exit codes (old style)
        set -l has_codes (echo "$json" | jq -r '.exitCodes | if . then keys | length else 0 end' 2>/dev/null)
        if test "$has_codes" -gt 0
            set_color --dim black
            echo "EXIT CODES"
            set_color normal
            echo "$json" | jq -r '.exitCodes | to_entries | sort_by(.key | tonumber) | .[] | "  \(.key)    \(.value)"' 2>/dev/null
            echo ""
        end
    end
end
