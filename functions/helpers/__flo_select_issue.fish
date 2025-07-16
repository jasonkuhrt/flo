function __flo_select_issue --description "Let user select from open issues"
    if not __flo_check_gh_auth
        return 1
    end
    
    set -l issues (gh issue list --json number,title --limit 20 2>/dev/null)
    
    if test -z "$issues" -o "$issues" = "[]"
        echo "No open issues found"
        return 1
    end
    
    echo "Open issues:"
    echo $issues | jq -r '.[] | "#\(.number) - \(.title)"' | nl -v 1
    
    read -P "Select issue (1-N): " selection
    
    if test -z "$selection"
        echo "No selection made"
        return 1
    end
    
    # Validate selection is a number
    if not string match -qr '^[0-9]+$' -- $selection
        echo "Invalid selection: $selection"
        return 1
    end
    
    # Get the issue number (array is 0-indexed, display is 1-indexed)
    set -l index (math $selection - 1)
    set -l issue_number (echo $issues | jq -r ".[$index].number" 2>/dev/null)
    
    if test -z "$issue_number" -o "$issue_number" = "null"
        echo "Invalid selection: $selection"
        return 1
    end
    
    echo $issue_number
end