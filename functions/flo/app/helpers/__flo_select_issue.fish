function __flo_select_issue --description "Let user select from open issues"
    argparse --name="__flo_select_issue" f/filter c/choose l/limit= -- $argv; or return

    if not __flo_check_gh_auth
        return 1
    end

    # Set default limit
    set -l limit 50
    if set -q _flag_limit
        set limit $_flag_limit
    end

    # Get issue count to decide between choose and filter (if not explicitly set)
    set -l use_filter 0
    if set -q _flag_filter
        set use_filter 1
    else if set -q _flag_choose
        set use_filter 0
    else
        # Auto-decide based on count
        set -l issue_count (gh issue list $FLO_GH_DEFAULT_LIMIT --json number --jq 'length' 2>/dev/null)
        if test -n "$issue_count" -a "$issue_count" -gt 10
            set use_filter 1
        end
    end

    # Get formatted issues using gh template for better performance
    set -l formatted_issues (gh issue list -L $limit --template '{{range .}}#{{.number}} - {{.title}}{{"\n"}}{{end}}' 2>/dev/null)

    if test -z "$formatted_issues"
        # No issues found - offer option to continue without issue
        set -l choice (gum choose \
            --header $FLO_HEADER_NO_ISSUES \
            $FLO_CHOICE_CONTINUE_WITHOUT_ISSUE \
            $FLO_CHOICE_CANCEL)

        if test "$choice" = $FLO_CHOICE_CONTINUE_WITHOUT_ISSUE
            # Show default pattern and prompt for optional custom suffix
            set -l default_name (date $FLO_TIMESTAMP_FORMAT)
            set -l default_preview "$FLO_NO_ISSUE_PREFIX$default_name"

            set -l custom_name (gum input \
                --placeholder $FLO_PLACEHOLDER_SUFFIX \
                --header "Will create: $default_preview (or no-issue/YOUR-INPUT if you type below)" \
                --width $FLO_INPUT_WIDTH)

            # Check if user pressed Ctrl+C
            if test $status -eq $FLO_CTRL_C_EXIT_CODE
                echo Cancelled $FLO_TO_STDERR
                return 1
            end

            if test -n "$custom_name"
                # Slugify the custom name and output the full identifier
                set -l slugified (__flo_slugify "$custom_name")
                echo "$FLO_NO_ISSUE:$slugified"
            else
                # Use default
                echo $FLO_NO_ISSUE
            end
            return 0
        else
            echo "No issue selected" $FLO_TO_STDERR
            return 1
        end
    end

    # Use appropriate UI based on decision
    if test $use_filter -eq 1
        # Use gum filter for fuzzy search
        set -l selected (echo -n $formatted_issues | gum filter \
            --placeholder "Type to filter issues..." \
            --header "Search issues:" \
            --height 15)
    else
        # Use gum choose for small lists
        set -l selected (echo -n $formatted_issues | gum choose \
            --header "Select an issue:" \
            --show-help)
    end

    if test -z "$selected"
        echo "No issue selected" >&2
        return 1
    end

    # Extract the issue number from the selection
    set -l issue_number (echo $selected | sed 's/^#\([0-9]*\).*/\1/')

    echo $issue_number
end
