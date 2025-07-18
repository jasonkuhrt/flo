function __flo_complete_issues --description "Complete issue numbers and titles for tab completion"
    if not gh auth status >/dev/null 2>&1
        return 1
    end

    # Simple caching - use a cache file with timestamp
    set -l cache_file "$HOME/.cache/flo/issues_complete"
    set -l cache_age_minutes 5

    # Create cache directory if it doesn't exist
    if not mkdir -p (dirname "$cache_file")
        # Silently fail - completion should not show errors
        return 1
    end

    # Check if cache exists and is fresh
    if test -f "$cache_file"
        # Use portable stat command that works on both macOS and Linux
        set -l cache_time
        if test (uname) = Darwin
            set cache_time (stat -f "%m" "$cache_file" 2>/dev/null; or echo 0)
        else
            set cache_time (stat -c "%Y" "$cache_file" 2>/dev/null; or echo 0)
        end
        set -l current_time (date +%s)
        set -l age_minutes (math "($current_time - $cache_time) / 60")

        if test $age_minutes -lt $cache_age_minutes
            cat "$cache_file"
            return
        end
    end

    # Fetch fresh data and cache it
    gh issue list --limit 20 --json number,title 2>/dev/null | jq -r '.[] | "\(.number)\t\(.title)"' >"$cache_file"
    cat "$cache_file"
end
