function __flo_prompt_claude_session --description "Prompt user for Claude session ID"
    # Use gum to get session ID with nice UI
    set -l session_id (gum input \
        --header "Resume Claude session?" \
        --placeholder "Enter session ID or press Enter to skip" \
        --prompt "> " \
        --width 50 \
        --help "Run '/status' in Claude to get your session ID")

    # If user pressed Ctrl+C, gum returns status 130
    if test $status -eq 130
        return 1
    end

    if test -n "$session_id"
        # Basic validation - should be UUID format
        if string match -qr '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' $session_id
            echo $session_id
        else
            echo "Invalid session ID format (should be UUID like: bbf041be-3b3c-4913-9b13-211921ef0048)" >&2
            return 1
        end
    end
end
