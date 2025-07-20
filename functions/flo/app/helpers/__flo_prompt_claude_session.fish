function __flo_prompt_claude_session --description "Prompt user for Claude session ID"
    # Use gum to get session ID with nice UI
    # Note: --help flag not supported by gum input, show instructions separately
    echo "To resume: Run '/status' in Claude and copy the Session ID" >&2
    echo "" >&2
    set -l session_id (gum input \
        --header "Resume Claude session?" \
        --placeholder "Enter session ID or press Enter to skip" \
        --prompt "> " \
        --width 50)

    # If user pressed Ctrl+C, gum returns status 130
    if test $status -eq $FLO_CTRL_C_EXIT_CODE
        return 1
    end

    if test -n "$session_id"
        # Basic validation - should be UUID format
        if string match -qr $FLO_UUID_PATTERN $session_id
            echo $session_id
        else
            echo "Invalid session ID format (should be UUID like: bbf041be-3b3c-4913-9b13-211921ef0048)" >&2
            return 1
        end
    end
end
