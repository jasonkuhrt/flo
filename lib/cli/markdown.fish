# Markdown utilities for CLI framework

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

function __cli_render_parameters_named --description "Render named parameters (flags/options) section"
    set -l json $argv[1]

    set -l param_count (echo "$json" | jq -r '.parametersNamed | length' 2>/dev/null)
    if test "$param_count" -gt 0
        set_color --dim black
        echo FLAGS
        set_color normal
        # Format: --flag, -f    Description
        echo "$json" | jq -r '.parametersNamed[] | "  \(.name)\(if .short then ", \(.short)" else "" end)    \(.description)"' 2>/dev/null
        echo ""
    end
end

function __cli_render_examples --description "Render examples section"
    set -l json $argv[1]

    set -l example_count (echo "$json" | jq -r '.examples | length' 2>/dev/null)
    if test "$example_count" -gt 0
        set_color --dim black
        echo EXAMPLES
        set_color normal
        # Format each example with command and optional description
        echo "$json" | jq -r '.examples[] | "  \(.command)\(if .description then "    # \(.description)" else "" end)"' 2>/dev/null
        echo ""
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

function __cli_render_exit_codes --description "Render exit codes section"
    set -l json $argv[1]

    # Check if exitCodes object exists and has keys
    set -l has_codes (echo "$json" | jq -r '.exitCodes | if . then keys | length else 0 end' 2>/dev/null)
    if test "$has_codes" -gt 0
        set_color --dim black
        echo "EXIT CODES"
        set_color normal
        # Sort by exit code number and format
        echo "$json" | jq -r '.exitCodes | to_entries | sort_by(.key | tonumber) | .[] | "  \(.key)    \(.value)"' 2>/dev/null
        echo ""
    end
end

function __cli_render_command_help --description "Render formatted help for a command from markdown"
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

    # Get description
    set -l desc (echo "$json" | jq -r '.description // empty' 2>/dev/null)

    # Leading newline for spacing
    echo ""

    # Title (just command name in cyan)
    set_color cyan
    echo "$__cli_name $cmd"
    set_color normal
    echo ""

    # Description paragraph
    if test -n "$desc"
        echo "$desc"
        echo ""
    end

    # Render POSITIONAL PARAMETERS section if they exist
    set -l param_count (echo "$json" | jq -r '.parametersPositional | length' 2>/dev/null)
    if test "$param_count" -gt 0
        set_color --dim black
        echo "POSITIONAL PARAMETERS"
        set_color normal
        # Use jq to format each parameter
        echo "$json" | jq -r '.parametersPositional[] | "  <\(.name)>    \(.description)"' 2>/dev/null
        echo ""
    end

    # Render FLAGS section
    __cli_render_parameters_named "$json"

    # Get and render guide content with markdown sections
    set -l guide_content (__cli_get_markdown_content "$doc_file")
    if test (count $guide_content) -gt 0
        __cli_render_markdown_sections $guide_content
    end

    # Render EXAMPLES section
    __cli_render_examples "$json"

    # Render SEE ALSO section
    __cli_render_related "$json"

    # Render EXIT CODES section
    __cli_render_exit_codes "$json"
end
