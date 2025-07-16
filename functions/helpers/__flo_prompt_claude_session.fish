function __flo_prompt_claude_session --description "Prompt user for Claude session ID"
    echo ""
    echo "To resume your Claude session:"
    echo "1. Run '/status' in Claude"
    echo "2. Copy the Session ID from output like:"
    echo "   Session ID: bbf041be-3b3c-4913-9b13-211921ef0048"
    echo ""
    
    read -P "Session ID (or Enter to skip): " session_id
    
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